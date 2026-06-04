# Phase 3 — DevOps Handoff

**Date:** 2026-05-21
**Branch:** `feature/aws-deployment`
**Scope:** Stand up the dmair-backend staging slot at `live/dmair/backend/staging/` — VPC, EC2 + EIP, RDS PostgreSQL 16 + PostGIS, ECR, Secrets Manager, CloudWatch, AWS Budget, and the dmair-backend-staging-deploy OIDC role.

**Hard prerequisite:** Phases 1 and 2 must be DevOps-applied first. Phase 3 doesn't touch any pre-existing resource, but its `terraform init` writes a new state object to `s3://dmair-terraform-prod/staging/backend/terraform.tfstate` — which requires Phase 1's state bucket adoption + `use_lockfile = true` to be in place.

---

## Pre-apply checklist

1. **Phase 1 + Phase 2 applied.** All four existing stacks (`bootstrap`, `live/dmair/strapi/prod`, `live/dmair/frontend/prod`, `live/dmair/frontend/staging`) report `terraform plan` → `No changes`.
2. **dmair AWS profile** is write-capable with at least:
   - `s3:Get/Put/Delete/ListBucket` on `arn:aws:s3:::dmair-terraform-prod`
   - `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreateInstanceProfile` for the **EC2 instance role** (Terraform-managed). The `dmair-backend-staging-deploy` OIDC role + the OIDC IDP itself are created out-of-band by ops per [`docs/iam-oidc/`](../../../docs/iam-oidc/), not by Terraform.
   - `ec2:*`, `vpc:*`, `rds:*`, `ecr:*`, `secretsmanager:*`, `logs:*`, `budgets:*`, `ssm:GetParameter` on the relevant scopes
3. **The four sensitive vars** are decided and ready:
   - `db_password` — strong, generated.
   - `jwt_secret_key` — HS512, ≥64 chars (e.g. `openssl rand -hex 64`).
   - `mail_password` — SendGrid API key (sandbox is fine for staging).
   - `admin_bootstrap_password` — 12–128 chars.
4. **GoDaddy DNS access** for the `flydmair.com` zone (you'll add an A record after the apply).
5. **Cross-repo coordination ready** — once the `dmair-backend-staging-deploy` role ARN is output by `terraform apply`, paste it into the `dmair-backend` repo's `.github/workflows/deploy-staging.yml`.

---

## Sequence to apply

### Step 1 — Populate sensitive values in SSM Parameter Store

The 4 sensitive values (`db_password`, `jwt_secret_key`, `mail_password`, `admin_bootstrap_password`) are **NOT** Terraform variables and **NOT** GitHub Secrets. They live in AWS Systems Manager Parameter Store as `SecureString` parameters and are read at `terraform plan` / `apply` time via `data "aws_ssm_parameter"` blocks in `ssm.tf`.

Create them once (or after rotation) per environment:

```sh
export AWS_PROFILE=<write-capable>
REGION=us-west-2

# db_password — RDS master/app user. 32-char random, ASCII-safe for RDS.
aws ssm put-parameter --type SecureString --tier Standard --region "$REGION" \
  --name /dmair/staging/db_password \
  --value "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+-=' </dev/urandom | head -c 32)"

# jwt_secret_key — HS512 signing key, 128 hex chars (>=64 required).
aws ssm put-parameter --type SecureString --tier Standard --region "$REGION" \
  --name /dmair/staging/jwt_secret_key \
  --value "$(openssl rand -hex 64)"

# mail_password — your SendGrid API key. Get from SendGrid → Settings → API Keys
# → Create API Key with permission 'Mail Send: Full Access'. Save it to a
# password manager when SendGrid shows it (one-time display).
aws ssm put-parameter --type SecureString --tier Standard --region "$REGION" \
  --name /dmair/staging/mail_password \
  --value "<paste-the-real-sendgrid-key>"

# admin_bootstrap_password — initial admin login (12-128 chars).
# Save this to a password manager — you'll use it for the very first admin
# login at https://staging-api.flydmair.com after the bootstrap container runs.
aws ssm put-parameter --type SecureString --tier Standard --region "$REGION" \
  --name /dmair/staging/admin_bootstrap_password \
  --value "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+-=' </dev/urandom | head -c 24)"
```

To **rotate** any of them later: same command with `--overwrite`. After rotation, run `terraform apply` to refresh the Secrets Manager secret (which the dmair-backend app reads at container start). For `db_password` specifically, also `-target=aws_db_instance.postgres` apply will push the new password to RDS.

The 3 terraform CI roles already have:
- `ssm:GetParameter*` via the broad refresh statement.
- `kms:Decrypt` scoped to `kms:ViaService=ssm.us-west-2.amazonaws.com` (the SecureString values are encrypted with the AWS-managed `aws/ssm` KMS key).

So once the parameters exist, CI plan + apply work end-to-end with no additional secrets.

### Step 2 — Init + plan + apply

```sh
cd live/dmair/backend/staging
terraform init
terraform plan      # expect ~30 to add, 0 to change, 0 to destroy
terraform apply     # answer yes
```

The `terraform apply` will take ~10–15 minutes (RDS provisioning dominates).

### Step 3 — Capture outputs

```sh
terraform output
```

You need:
- `elastic_ip` → DNS A record
- `ec2_instance_id` → for the SSM session command
- `ecr_repository_url` → for the dmair-backend CI / first image push
- (the dmair-backend-staging-deploy role ARN comes from the manually-created role per `docs/iam-oidc/` — not output by Terraform)
- `rds_endpoint` → sanity-check vs application config

### Step 4 — Point DNS at the EIP (GoDaddy)

Log in to GoDaddy DNS for `flydmair.com`. Add or update:

| Type | Name | Value | TTL |
|---|---|---|---|
| `A` | `api-staging` | `<elastic_ip from step 3>` | 600 |

Verify:
```sh
dig +short staging-api.flydmair.com
# must return the same IP as terraform output elastic_ip
```

DNS must resolve BEFORE the first request to `staging-api.flydmair.com` — otherwise Caddy can't complete its ACME (Let's Encrypt) challenge and the cert won't issue.

### Step 5 — Push the first dmair-backend image to ECR

From the dmair-backend repo (`/Users/mithin/Projects/DMAir/dmair-backend/` locally):

```sh
cd /Users/mithin/Projects/DMAir/dmair-backend
./mvnw clean package -DskipTests
docker build --platform linux/arm64 -t dmair-backend:$(git rev-parse --short HEAD) .

aws --profile dmair ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin <ecr_repository_url from terraform output>

docker tag dmair-backend:<sha> <ecr_repository_url>:<sha>
docker push <ecr_repository_url>:<sha>

# Optional: also tag :staging-latest so the EC2 user-data's default app_image works
docker tag dmair-backend:<sha> <ecr_repository_url>:staging-latest
docker push <ecr_repository_url>:staging-latest
```

### Step 6 — Restart the dmair-staging systemd unit so it picks up the image

```sh
aws --profile dmair ssm start-session --target <ec2_instance_id>
# inside the SSM session:
sudo systemctl restart dmair-staging.service
sudo journalctl -u dmair-staging.service -n 50 --no-pager
exit
```

Watch the logs for ECR pull + container start. Caddy will spin up and request the Let's Encrypt cert on the first inbound request.

### Step 7 — Smoke-test

```sh
# Should return 200 with {"status":"UP"} once Caddy has the cert
curl -sS https://staging-api.flydmair.com/actuator/health
```

### Step 8 — Bootstrap the first admin (spec §6.3)

**Blocker:** this requires dmair-backend's `AdminBootstrapRunner` create-or-activate mode (spec §8.1(b)) to be merged. Without it, this step falls back to the activation-link flow per the spec's caveat.

```sh
aws --profile dmair ssm start-session --target <ec2_instance_id>
# inside SSM:
cd /opt/dmair
eval "$(aws secretsmanager get-secret-value --secret-id dmair/staging/app \
  --region us-west-2 --query SecretString --output text \
  | jq -r 'to_entries[] | "export \(.key)=\(.value | @sh)"')"
docker compose --profile bootstrap run --rm admin-bootstrap
exit
```

### Step 9 — STAGING-03 deny-by-exclusion verification

Assume the OIDC role locally (or in a sandbox Action) and run the verification commands in [`VERIFICATION.md`](./VERIFICATION.md) §STAGING-03. Paste evidence.

### Step 10 — Fill VERIFICATION.md + commit

Open [`VERIFICATION.md`](./VERIFICATION.md). Paste pasted outputs into each `TODO_DEVOPS:` block. Tick all four Phase Exit checkboxes. Set Outcome = PASS. Commit:

```
docs(STAGING-03): record staging slot verification evidence
```

Then `/gsd-transition` to advance to Phase 4.

---

## Rollback

To roll back the entire staging backend slot:

```sh
cd live/dmair/backend/staging

# EIP has prevent_destroy = true — must remove the lifecycle block first if you
# really want to destroy it (which breaks the DNS record at GoDaddy).
# Comment out the lifecycle{} block in ec2.tf, then:
terraform plan -destroy   # review carefully
terraform destroy         # answer yes

# Then revert the Phase 3 commits:
git revert <phase-3-shas>
```

The OIDC identity provider + the 4 OIDC-trusted IAM roles are **not** managed by this Terraform stack — they're created out-of-band by ops per [`docs/iam-oidc/`](../../../docs/iam-oidc/). A Phase 3 destroy does NOT touch them.

---

## What this phase does NOT do

- **No CI/CD workflow.** Phase 4 ships `.github/workflows/terraform.yml` + the dmair-terraform CI OIDC role. Phase 3 only ships the dmair-backend-staging-deploy role (consumed by the dmair-backend repo's CI).
- **No DNS automation.** GoDaddy is external; the A record is created by hand.
- **No image push.** Phase 3 creates the empty ECR repo; the first image push is an operator step (see Step 5).
- **No admin user creation.** Operator runs the bootstrap container via SSM (Step 8).
- **No staging-frontend changes.** `live/dmair/frontend/staging/` is untouched.
