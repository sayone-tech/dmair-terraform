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
   - `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreateInstanceProfile`, etc. for the dmair-backend-staging-deploy role + the EC2 instance role (the OIDC IDP itself is created by `platform/oidc/`, not here)
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

### Step 1 — Populate sensitive variables

Either of:

**(a) Local tfvars (gitignored):**
```sh
cd live/dmair/backend/staging
cp staging.auto.tfvars.example staging.auto.tfvars
# Edit staging.auto.tfvars — replace the four REPLACE_WITH_* values
```

**(b) CI environment:**
```sh
export TF_VAR_db_password=...
export TF_VAR_jwt_secret_key=...
export TF_VAR_mail_password=...
export TF_VAR_admin_bootstrap_password=...
```

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
- `dmair_backend_staging_deploy_role_arn` → for the dmair-backend repo's deploy workflow
- `rds_endpoint` → sanity-check vs application config

### Step 4 — Point DNS at the EIP (GoDaddy)

Log in to GoDaddy DNS for `flydmair.com`. Add or update:

| Type | Name | Value | TTL |
|---|---|---|---|
| `A` | `api-staging` | `<elastic_ip from step 3>` | 600 |

Verify:
```sh
dig +short api-staging.flydmair.com
# must return the same IP as terraform output elastic_ip
```

DNS must resolve BEFORE the first request to `api-staging.flydmair.com` — otherwise Caddy can't complete its ACME (Let's Encrypt) challenge and the cert won't issue.

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
curl -sS https://api-staging.flydmair.com/actuator/health
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

The OIDC identity provider (`aws_iam_openid_connect_provider.github`) is account-wide and managed by `platform/oidc/` — not by this stack. A Phase 3 destroy removes only the `dmair-backend-staging-deploy` role; the IDP and the terraform CI roles in `platform/oidc/` stay intact.

---

## What this phase does NOT do

- **No CI/CD workflow.** Phase 4 ships `.github/workflows/terraform.yml` + the dmair-terraform CI OIDC role. Phase 3 only ships the dmair-backend-staging-deploy role (consumed by the dmair-backend repo's CI).
- **No DNS automation.** GoDaddy is external; the A record is created by hand.
- **No image push.** Phase 3 creates the empty ECR repo; the first image push is an operator step (see Step 5).
- **No admin user creation.** Operator runs the bootstrap container via SSM (Step 8).
- **No staging-frontend changes.** `live/dmair/frontend/staging/` is untouched.
