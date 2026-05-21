---
phase: 03-dmair-backend-staging-slot
plan: 02
status: code-only-complete
---

# Plan 03-02 Summary — user-data.sh EC2 bootstrap

## Status

**code-only-complete.** Bash script rendered into EC2 user-data via `templatefile()` in `ec2.tf`. Mirrors `DMAir/dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` §6.1 + §6.2 + §10.13.

## What it does on first boot

1. `apt-get` Docker Engine + Compose plugin + `jq` + `unzip` + `curl`.
2. Installs AWS CLI v2 (ARM64).
3. Writes `/opt/dmair/docker-compose.staging.yml` with services `caddy`, `app`, `valkey`, `admin-bootstrap` (the last under a `bootstrap` profile so it doesn't start by default).
4. Writes `/opt/dmair/Caddyfile` reverse-proxying to `app:8080` and 403'ing diagnostic actuator paths at the edge.
5. Writes `/opt/dmair/start.sh` — fetches the consolidated `dmair/staging/app` Secrets Manager secret into the process env (never to disk), `docker login` to ECR, `docker compose pull` + `up -d`.
6. Registers `dmair-staging.service` systemd unit; starts it.

## Subtleties

- **Templatefile() vs docker-compose `$${}`:** the docker-compose YAML uses `$${VAR}` (double-dollar) so Terraform's `templatefile()` leaves them alone. Non-Terraform string interpolations use `__PLACEHOLDER__` markers and a `sed` pass at the bottom of the script — avoids collision.
- **First-start failure is expected:** if ECR has no image yet, `docker pull` fails and the systemd unit exits non-zero. The script catches this and prints a one-liner pointing at the recovery command. Operator pushes the first image, then `sudo systemctl restart dmair-staging.service`.
- **No `.env` written:** secrets exist only in the process environment of `start.sh` → `docker compose` env interpolation → the container's env. Never persisted to the EBS volume.

## Commit

`6a7636e` `feat(STAGING-01): user-data.sh bootstrap for staging EC2`.

## Key files (created)

- `live/dmair/staging/backend/user-data.sh`
