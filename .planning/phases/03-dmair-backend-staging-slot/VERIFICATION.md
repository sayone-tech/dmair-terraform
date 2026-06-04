# Phase 3: dmair-backend Staging Slot — Verification Evidence

**Status:** TEMPLATE — pending DevOps execution.

**Date:** _(YYYY-MM-DD)_
**Verifier:** _(DevOps name)_
**Outcome:** _PASS / FAIL_

---

## STAGING-01 — `terraform apply` provisions the full staging stack

```sh
cd live/dmair/backend/staging
# Set TF_VAR_db_password / jwt_secret_key / mail_password / admin_bootstrap_password
# OR populate staging.auto.tfvars (gitignored). Use staging.auto.tfvars.example as the template.
terraform init
terraform plan
terraform apply
terraform plan   # follow-up — must report "No changes."
```

### Pasted output

```text
TODO_DEVOPS: paste the final summary line from `terraform apply` (Plan: X to add, 0 to change, 0 to destroy + Apply complete!).
```

```text
TODO_DEVOPS: paste the follow-up `terraform plan` line `No changes. Your infrastructure matches the configuration.`
```

### Stack inventory check (sampled)

```sh
aws --profile dmair ec2 describe-instances --filters Name=tag:Name,Values=dmair-staging-ec2 --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'
aws --profile dmair rds describe-db-instances --db-instance-identifier dmair-staging --query 'DBInstances[].{Endpoint:Endpoint.Address,Status:DBInstanceStatus,Storage:AllocatedStorage}'
aws --profile dmair ecr describe-repositories --repository-names dmair-backend --query 'repositories[].repositoryUri'
aws --profile dmair secretsmanager describe-secret --secret-id dmair/staging/app --query 'ARN'
aws --profile dmair logs describe-log-groups --log-group-name-prefix /dmair/staging --query 'logGroups[].{Name:logGroupName,Retention:retentionInDays}'
aws --profile dmair budgets describe-budgets --account-id <acct> --query "Budgets[?BudgetName=='dmair-staging-monthly']"
```

```text
TODO_DEVOPS: paste outputs from the six commands above (or screenshot the AWS console equivalent). Confirm:
  - EC2 t4g.medium running with public IP attached
  - RDS dmair-staging available with the expected endpoint
  - ECR dmair-backend repo URL
  - Secrets Manager dmair/staging/app exists
  - /dmair/staging log group with retentionInDays=5
  - AWS Budget dmair-staging-monthly at $60 limit
```

---

## STAGING-02 — Existing live stacks untouched

```sh
for stack in bootstrap live/dmair/strapi/prod live/dmair/frontend/prod live/dmair/frontend/staging; do
  echo "=== $stack ==="
  (cd "$stack" && terraform plan)
done
```

Each must report `No changes. Your infrastructure matches the configuration.`

```text
TODO_DEVOPS: paste four No-changes outputs (one per stack).
```

---

## STAGING-02b — DNS resolves to the staging backend EIP

After the operator creates the A record at GoDaddy (`staging-api.flydmair.com` → EIP from terraform output):

```sh
dig +short staging-api.flydmair.com
```

Expected: the same IP as `terraform output elastic_ip`.

```text
TODO_DEVOPS: paste `dig +short` output. Confirm it matches `terraform output elastic_ip`.
```

After the first image is pushed and Caddy obtains its Let's Encrypt cert:

```sh
curl -sS -o /dev/null -w "%{http_code}\n" https://staging-api.flydmair.com/actuator/health
```

Expected: a non-TLS-error HTTP response (200/403/404 — anything that proves TLS works).

```text
TODO_DEVOPS: paste curl status code. 200 = ideal; 401/403/404 also count as "TLS works".
```

---

## STAGING-03 — OIDC deny-by-exclusion

Assume the `dmair-backend-staging-deploy` role via STS (locally or in a sandboxed GitHub Action). Then verify both directions:

### Allowed: read/write under `live/dmair/staging/*`

```sh
# As dmair-backend-staging-deploy:
aws ecr describe-repositories --repository-names dmair-backend
aws secretsmanager describe-secret --secret-id dmair/staging/app
aws ssm describe-instance-information --filters Key=tag:Name,Values=dmair-staging-ec2
```

Expected: all three succeed.

```text
TODO_DEVOPS: paste 3 success outputs.
```

### Denied: cms-* / frontend-* / strapi-* resources

```sh
# Same role context — these MUST return AccessDenied:
aws s3api get-bucket-policy --bucket <strapi-cms-media-bucket>      # cms-* / strapi-* resource
aws ecr describe-repositories --repository-names <frontend-ecr>     # frontend-* repo (if exists)
aws secretsmanager describe-secret --secret-id <any-other-secret>   # any non-dmair/staging/app secret
```

Each must return `AccessDenied` / `not authorized` / `is not authorized to perform`.

```text
TODO_DEVOPS: paste three AccessDenied error outputs. This is the deny-by-exclusion evidence.
```

---

## Phase Exit

- [ ] **STAGING-01** — `terraform apply` provisions the full stack; follow-up `terraform plan` says `No changes`
- [ ] **STAGING-02** — all four pre-existing stacks plan `No changes` after the apply
- [ ] **STAGING-02b** — DNS resolves and HTTPS works end-to-end
- [ ] **STAGING-03** — dmair-backend-staging-deploy role works on staging resources AND is denied on cms-* / frontend-* / strapi-* resources

Set Outcome above. Commit with `docs(STAGING-03): record staging slot verification evidence`. Then `/gsd-transition` to advance to Phase 4.
