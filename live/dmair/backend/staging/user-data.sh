#!/bin/bash
# user-data.sh — dmair-backend staging EC2 bootstrap.
#
# Rendered by Terraform via templatefile() with these substitutions:
#   ${aws_region}    — e.g. us-west-2
#   ${secret_id}     — Secrets Manager secret name, e.g. dmair/staging/app
#   ${app_image}     — full ECR image URI:tag for the dmair-backend container
#   ${ecr_registry}  — ECR registry hostname, e.g. 071297531943.dkr.ecr.us-west-2.amazonaws.com
#   ${db_endpoint}   — RDS hostname (no port)
#   ${db_name}       — logical DB name (e.g. dmair)
#   ${db_username}   — RDS app user (e.g. dmair_app)
#   ${domain}        — public hostname (e.g. api-staging.flydmair.com)
#
# Mirrors DMAir/dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md
# §6.1 + §6.2 + §10.13. Writes docker-compose.staging.yml + Caddyfile +
# start.sh to /opt/dmair, registers a systemd unit, starts the stack.
# Secrets reach the containers via process environment only — no .env
# file is written to disk.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---- Base packages -------------------------------------------------------
apt-get update
apt-get install -y \
    docker.io \
    docker-compose-v2 \
    jq \
    unzip \
    curl
systemctl enable --now docker

# ---- AWS CLI v2 (ARM64) — Ubuntu's apt awscli is v1 ---------------------
# amazon-ssm-agent is preinstalled via snap on Canonical's Ubuntu Server AMIs.
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscli.zip
unzip -q /tmp/awscli.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/awscli.zip /tmp/aws

mkdir -p /opt/dmair
cd /opt/dmair

# ---- docker-compose.staging.yml -----------------------------------------
# Non-secret config inline; secret vars interpolated from start.sh's
# environment (sourced from Secrets Manager).
cat > /opt/dmair/docker-compose.staging.yml <<'COMPOSE'
services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on: [app]
    logging:
      driver: awslogs
      options:
        awslogs-region: __AWS_REGION__
        awslogs-group: /dmair/staging
        awslogs-stream: caddy

  app:
    image: __APP_IMAGE__
    restart: unless-stopped
    expose: ["8080"]              # internal only — NOT published to host
    depends_on: [valkey]
    environment: &app-env
      SPRING_PROFILE: staging
      SERVER_PORT: "8080"
      DB_URL: "jdbc:postgresql://__DB_ENDPOINT__:5432/__DB_NAME__"
      DB_USERNAME: __DB_USERNAME__
      REDIS_HOST: valkey
      REDIS_PORT: "6379"
      FLYWAY_ENABLED: "true"
      FLYWAY_BASELINE_ON_MIGRATE: "false"
      MAIL_HOST: smtp.sendgrid.net
      MAIL_PORT: "587"
      MAIL_USERNAME: apikey
      MAIL_SMTP_AUTH: "true"
      MAIL_SMTP_STARTTLS: "true"
      MAIL_FROM: no-reply@flydmair.com
      APP_URL: "https://__DOMAIN__"
      FRONTEND_BASE_URL: "https://__DOMAIN__"
      CORS_ALLOWED_ORIGINS: "https://__DOMAIN__"
      ACTUATOR_ENDPOINTS: health,info,metrics,prometheus
      JWT_SECRET_KEY: $${JWT_SECRET_KEY:?from Secrets Manager}
      DB_PASSWORD: $${DB_PASSWORD:?from Secrets Manager}
      MAIL_PASSWORD: $${MAIL_PASSWORD:?from Secrets Manager}
    logging:
      driver: awslogs
      options:
        awslogs-region: __AWS_REGION__
        awslogs-group: /dmair/staging
        awslogs-stream: app

  valkey:
    image: valkey/valkey:8
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-region: __AWS_REGION__
        awslogs-group: /dmair/staging
        awslogs-stream: valkey

  admin-bootstrap:
    image: __APP_IMAGE__
    profiles: ["bootstrap"]
    depends_on: [valkey]
    command: ["--admin-bootstrap"]
    environment:
      <<: *app-env
      ADMIN_BOOTSTRAP_PASSWORD: $${ADMIN_BOOTSTRAP_PASSWORD:?from Secrets Manager}
    logging:
      driver: awslogs
      options:
        awslogs-region: __AWS_REGION__
        awslogs-group: /dmair/staging
        awslogs-stream: admin-bootstrap

volumes:
  caddy_data:
  caddy_config:
COMPOSE

# Substitute the templatefile() variables (using sed because we used a
# 'COMPOSE' heredoc above to keep the YAML literal-safe — Terraform's
# dollar-brace interpolation would otherwise collide with docker
# compose's double-dollar-brace escape sequences.
sed -i \
    -e "s|__AWS_REGION__|${aws_region}|g" \
    -e "s|__APP_IMAGE__|${app_image}|g" \
    -e "s|__DB_ENDPOINT__|${db_endpoint}|g" \
    -e "s|__DB_NAME__|${db_name}|g" \
    -e "s|__DB_USERNAME__|${db_username}|g" \
    -e "s|__DOMAIN__|${domain}|g" \
    /opt/dmair/docker-compose.staging.yml

# ---- Caddyfile -----------------------------------------------------------
cat > /opt/dmair/Caddyfile <<EOF
${domain} {
    reverse_proxy app:8080

    @actuator path /actuator/heapdump /actuator/threaddump /actuator/env* /actuator/loggers*
    respond @actuator 403
}
EOF

# ---- start.sh — launcher ------------------------------------------------
# Run by the dmair-staging systemd unit at boot and on every CI deploy.
# Pulls the consolidated secret into its own environment (never to disk),
# logs in to ECR, and (re)starts the stack.
cat > /opt/dmair/start.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd /opt/dmair

# Secrets -> process environment only (no file on disk)
eval "\$(aws secretsmanager get-secret-value --secret-id ${secret_id} \\
    --region ${aws_region} --query SecretString --output text \\
    | jq -r 'to_entries[] | "export \\(.key)=\\(.value | @sh)"')"

aws ecr get-login-password --region ${aws_region} \\
    | docker login --username AWS --password-stdin ${ecr_registry}

docker compose -f docker-compose.staging.yml pull
docker compose -f docker-compose.staging.yml up -d
docker image prune -f
EOF
chmod +x /opt/dmair/start.sh

# ---- systemd unit --------------------------------------------------------
cat > /etc/systemd/system/dmair-staging.service <<'UNIT'
[Unit]
Description=DMAir Backend Staging (Docker Compose)
After=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/dmair
ExecStart=/opt/dmair/start.sh
ExecStop=/usr/bin/docker compose -f /opt/dmair/docker-compose.staging.yml down
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable dmair-staging.service

# First start. If the app image hasn't been pushed yet, this fails; that's
# expected — the operator pushes the image, then re-runs:
#   sudo systemctl restart dmair-staging.service
systemctl start dmair-staging.service || \
    echo "[user-data] dmair-staging.service first-start failed — likely missing app image in ECR. Push the image then: sudo systemctl restart dmair-staging.service"
