# Codebase Concerns

**Analysis Date:** 2026-05-20

---

## Tech Debt

**S3 backend missing encryption, DynamoDB locking, and versioning config:**
- Issue: All three backend configurations omit `encrypt = true`, `dynamodb_table`, and there is no evidence a state-locking DynamoDB table is provisioned. If two operators run `terraform apply` concurrently, state corruption is likely.
- Files: `envs/frontend/prod/backend.tf`, `envs/frontend/staging/backend.tf`, `envs/strapi/backend.tf`
- Impact: State file is stored in plaintext in S3; concurrent applies can corrupt state; no automatic recovery from failed applies.
- Fix approach: Add `encrypt = true` to all three backend blocks. Create a DynamoDB table (e.g. `dmair-terraform-lock`) with a `LockID` hash key and add `dynamodb_table = "dmair-terraform-lock"` to each backend. Enable versioning on the `dmair-terraform-prod` bucket via a separate Terraform workspace or manually.

**S3 state bucket shared across all environments with no isolation:**
- Issue: All three workspaces (frontend/prod, frontend/staging, strapi) write to the same bucket `dmair-terraform-prod`. Only the `key` path differs. There is no bucket policy restricting which IAM principal can write which key prefix.
- Files: `envs/frontend/prod/backend.tf`, `envs/frontend/staging/backend.tf`, `envs/strapi/backend.tf`
- Impact: A compromised or over-permissioned operator can overwrite any environment's state. Staging can accidentally destroy prod state.
- Fix approach: Add an S3 bucket policy that restricts each CI/CD role to its own key prefix, or use separate state buckets per environment.

**No `required_version` constraint on Terraform CLI:**
- Issue: None of the `terraform {}` blocks declare `required_version`. The provider is pinned to `5.91.0` in providers.tf, but the Terraform CLI version is unconstrained.
- Files: `envs/frontend/prod/providers.tf`, `envs/frontend/staging/providers.tf`, `envs/strapi/providers.tf`
- Impact: A developer running an older Terraform CLI version (e.g. 0.14) will produce unpredictable plan output or silent plan differences.
- Fix approach: Add `required_version = ">= 1.5.0"` (or appropriate floor) inside each `terraform {}` block in providers.tf.

**Module sources are local paths only — no versioning or registry references:**
- Issue: Every module is referenced with a relative local path (e.g. `source = "../../../modules/s3"`). There is no `version` attribute and no Git tag pinning.
- Files: All `envs/*/main.tf` files
- Impact: Any developer editing a module immediately affects all environments. No safe way to test a module change against staging before prod.
- Fix approach: Publish modules to a private Terraform registry or use Git source references with `?ref=vX.Y.Z` tags (e.g. `source = "git::https://github.com/org/repo.git//modules/s3?ref=v1.2.0"`).

**Strapi S3 bucket does not pass `AWS_S3_ignore_public_acls`:**
- Issue: `envs/strapi/main.tf` (module `app_s3_bucket`) passes `block_public_acls`, `block_public_policy`, and `restrict_public_buckets`, but does not pass `AWS_S3_ignore_public_acls`. The module variable defaults to `true`, so the current behaviour is safe, but the omission is inconsistent and fragile — if the module default ever changes the bucket could accept public ACLs silently.
- Files: `envs/strapi/main.tf` (lines 19–23), `envs/strapi/variables.tf`
- Impact: Low currently; medium risk if module defaults change.
- Fix approach: Explicitly pass `AWS_S3_ignore_public_acls = var.AWS_S3_ignore_public_acls` and add the variable to `envs/strapi/variables.tf`.

**`enable_versioning = false` on all content S3 buckets:**
- Issue: All three environments explicitly disable S3 versioning (comment: "Disable new features to match existing infrastructure"). S3 versioning prevents accidental overwrites and enables point-in-time recovery.
- Files: `envs/frontend/prod/main.tf` (line 22), `envs/frontend/staging/main.tf` (lines 22, 129), `envs/strapi/main.tf` (no explicit flag — module default is `false`)
- Impact: An accidental `aws s3 sync` wipe or a failed deploy that half-uploads assets has no rollback path.
- Fix approach: Enable versioning on prod buckets. Add an S3 lifecycle rule to expire non-current versions after 30–90 days to control cost.

**`s3_domain` and `s3_regional_domain` passed as the same value in all CloudFront modules:**
- Issue: The CloudFront module declares two separate input variables (`s3_domain` and `s3_regional_domain`) but all callers set them to the same output (`module.S3_Website.S3-Bucket-Domain`). The `s3_domain` variable is never used in `modules/cloudfront/main.tf`.
- Files: `envs/frontend/prod/main.tf` (lines 43–44), `envs/frontend/staging/main.tf` (lines 47–48, 136–137), `envs/strapi/main.tf` (lines 36–37), `modules/cloudfront/variables.tf`
- Impact: Dead variable adds confusion and maintenance burden.
- Fix approach: Remove `s3_domain` from `modules/cloudfront/variables.tf` and all callers, or consolidate to a single `s3_regional_domain` input.

**SES IAM user and policy are commented-out dead code:**
- Issue: The SES IAM user, policy module, and associated variables are commented out in `envs/strapi/main.tf` (lines 134–158) and in `envs/strapi/variables.tf` (lines 207–218) and `envs/strapi/output.tf` (lines 56–64). The SES policy template still exists at `policies/ses_send_mail.tpl`.
- Files: `envs/strapi/main.tf`, `envs/strapi/variables.tf`, `envs/strapi/output.tf`, `policies/ses_send_mail.tpl`
- Impact: Dead code accumulates, future developers may accidentally uncomment partial blocks. Template file has no active user.
- Fix approach: Either complete and enable SES configuration or remove all commented-out SES blocks and the unused template.

---

## Security Considerations

**Plaintext base64-encoded Basic Auth credentials committed to git:**
- Risk: `envs/frontend/staging/terraform.tfvars` contains `basic_auth_credentials = "c2F5b25lYWRtaW46QVNERkAjMTIzNA=="`. This decodes to `sayoneadmin:ASDF@#1234`. The comment in the same file even documents how to decode it: `echo -n "sayoneadmin:ASDF@#1234" | base64`.
- Files: `envs/frontend/staging/terraform.tfvars` (lines 25–26)
- Current mitigation: The `.gitignore` has `*.tfvars` commented out, meaning tfvars files ARE tracked in git. This credential is in version history.
- Recommendations: (1) Rotate the Basic Auth password immediately. (2) Move the credential to an environment variable passed at CI time (`TF_VAR_basic_auth_credentials`). (3) Uncomment `*.tfvars` in `.gitignore` and store tfvars outside the repository or use `sensitive` variable files. (4) Consider using a CloudFront signed URL or Cognito instead of Basic Auth for staging access control.

**Hardcoded SSH public key for Jenkins committed in a shell script:**
- Risk: `envs/strapi/startup_exact.sh` hardcodes a full RSA public key for a `jenkins-server` user directly in the file body (line 10). This is a parallel artifact alongside the template `startup.sh.tmpl` which uses variable injection. The exact script appears to be the active version (referenced in `envs/strapi/main.tf` line 232).
- Files: `envs/strapi/startup_exact.sh`, `envs/strapi/main.tf` (line 232)
- Current mitigation: It is a public key (not private), so credential leakage risk is low. However, the key cannot be rotated without changing committed code.
- Recommendations: Replace the reference in `main.tf` with `startup.sh.tmpl`, inject `jenkins_ssh_public_key` via `var.jenkins_ssh_public_key` (variable already exists in `variables.tf`). Delete `startup_exact.sh`.

**Hardcoded GitHub Actions SSH public key in `terraform.tfvars`:**
- Risk: `envs/strapi/terraform.tfvars` line 28 contains a full `ssh-ed25519` public key. As with above, public keys in git are low direct risk but rotation requires a commit.
- Files: `envs/strapi/terraform.tfvars` (line 28)
- Recommendations: Move SSH public keys to AWS SSM Parameter Store and read them via `data "aws_ssm_parameter"` at plan time, keeping the file free of any key material.

**Hardcoded local IP address `115.245.232.43/32` for SSH access in shared module:**
- Risk: `modules/sg/main.tf` line 37 hardcodes a specific developer's home/office IP as a permanent SSH ingress rule. This is committed to all security groups that use `use_default_rules = true`, including production (strapi env uses `sg_use_default_rules = true`).
- Files: `modules/sg/main.tf` (line 37)
- Current mitigation: None.
- Recommendations: Replace with a variable (e.g. `var.developer_ips` as a list) in `modules/sg/variables.tf` and pass it from each env's `terraform.tfvars`. The IP should not live in the module itself.

**Hardcoded AWS account ID in ACM certificate ARNs and S3 backup ARN:**
- Risk: The AWS account ID `071297531943` is embedded in plaintext in two tfvars files and in `envs/strapi/main.tf`. The S3 backup bucket `arn:aws:s3:::dmair-strapi-s3-backup` is also hardcoded.
- Files: `envs/frontend/prod/terraform.tfvars` (line 18), `envs/frontend/staging/terraform.tfvars` (line 18), `envs/strapi/terraform.tfvars` (line 8), `envs/strapi/main.tf` (lines 181–182)
- Current mitigation: ARNs are not secret, but embedding account IDs makes cross-account reuse impossible and aids attackers in crafting targeted resource policies.
- Recommendations: Use `data "aws_caller_identity" "current" {}` and reference `data.aws_caller_identity.current.account_id` to construct ARNs dynamically. Parameterise the backup bucket name as a variable.

**ECR repository uses `MUTABLE` image tags:**
- Risk: `envs/strapi/main.tf` line 58 sets `image_tag_mutability = "MUTABLE"`. An attacker with ECR push access can overwrite the `latest` tag to inject a malicious image without changing any deployment configuration.
- Files: `envs/strapi/main.tf` (line 58), `modules/ecr/variables.tf` (default is also `MUTABLE`)
- Current mitigation: ECR scan on push is enabled.
- Recommendations: Change to `IMMUTABLE` for production and use unique image tags (e.g. git SHA) for deployments. Update the ECR lifecycle policy `tagPrefixList` accordingly.

**Secrets Manager `recovery_window_in_days = 0` (force-delete):**
- Risk: `modules/secrets_manager/variables.tf` line 19 defaults `recovery_window_in_days` to `0`. A value of `0` forces immediate deletion with no recovery window, bypassing the normal 7–30 day protection.
- Files: `modules/secrets_manager/variables.tf` (line 19), `envs/frontend/prod/main.tf` (line 65), `envs/frontend/staging/main.tf` (line 69), `envs/strapi/main.tf` (line 26)
- Current mitigation: None. All secrets manager instances inherit this default.
- Recommendations: Change the default to `recovery_window_in_days = 7` (minimum non-zero AWS value). Override to `0` explicitly only where intentional (e.g. CI teardown).

**CloudFront function runtime is deprecated `cloudfront-js-1.0`:**
- Risk: `modules/cloudfront-function/main.tf` line 3 uses `cloudfront-js-1.0`. AWS introduced `cloudfront-js-2.0` with ES2022 support and additional capabilities. While `1.0` is not yet sunset, using it adds future upgrade risk.
- Files: `modules/cloudfront-function/main.tf` (line 3)
- Recommendations: Migrate to `cloudfront-js-2.0` when convenient. The `basic_auth.js` and `url_rewrite.js` code is simple ES5 and compatible.

---

## Performance Bottlenecks

**CloudFront `PriceClass_All` used for staging distribution:**
- Problem: `modules/cloudfront/main.tf` line 99 hardcodes `price_class = "PriceClass_All"`. For staging, this is unnecessary and incurs cost across all edge locations globally.
- Files: `modules/cloudfront/main.tf` (line 99)
- Improvement path: Make `price_class` a module variable defaulting to `"PriceClass_100"` (US/Europe/Japan only) and override to `"PriceClass_All"` only for production environments.

**EC2 root volume `12 GB` is undersized for a Docker-based Strapi workload:**
- Problem: `envs/strapi/terraform.tfvars` line 22 sets `EC2_ROOT_VOLUME_SIZE = 12`. A production instance running Docker, Docker Compose, two container images (Strapi + Nginx), and a local MySQL instance will exhaust this quickly.
- Files: `envs/strapi/terraform.tfvars` (line 22), `modules/ec2/variables.tf` (default is `20`)
- Improvement path: Increase to at least `30` GB for production. Add a CloudWatch disk utilisation alarm.

---

## Fragile Areas

**Security group `lifecycle { ignore_changes = [ingress] }` silently hides drift:**
- Files: `modules/sg/main.tf` (lines 6–8)
- Why fragile: GitHub Actions adds/removes its runner IP dynamically during deployments. The `ignore_changes` on `ingress` prevents Terraform from ever reconciling or removing stale rules left by crashed or interrupted CI runs. Over time the security group accumulates orphaned ingress rules.
- Safe modification: Remove the `ignore_changes` block and instead manage the ephemeral GitHub Actions IP using the `sg_manage` IAM policy exclusively through the GitHub Actions workflow (add before SSH, remove after), not as a permanent Terraform-managed rule.
- Test coverage: None — no tests exist in this repository.

**`modules/ec2/main.tf` `ignore_changes` list includes `ami` and `key_name`:**
- Files: `modules/ec2/main.tf` (lines 46–54)
- Why fragile: Ignoring `ami` means a security patch requiring an AMI update will never be applied by Terraform after the initial launch. The instance will silently drift from the declared AMI. Ignoring `key_name` means a key rotation performed through Terraform will have no effect on the running instance.
- Safe modification: Remove `ami` and `key_name` from `ignore_changes`. Handle AMI updates via a blue-green deployment or allow instance replacement. Rotate keys with explicit `terraform taint` or replacement.

**`prevent_destroy = true` on CloudFront, EC2, and EIP without documented escape hatch:**
- Files: `modules/cloudfront/main.tf` (line 127), `modules/ec2/main.tf` (line 53), `modules/eip/main.tf` (line 13)
- Why fragile: `prevent_destroy` blocks `terraform destroy` and environment teardown. There is no documented process for overriding it (e.g. removing the block for a planned decommission).
- Safe modification: Document the override procedure in each module's README. Consider removing `prevent_destroy` from the cloudfront and eip modules (lower-risk resources) and keeping it only on the EC2 instance.

**CloudFront module does not output `cdn_distribution_id` from the frontend prod env:**
- Files: `envs/frontend/prod/output.tf` (lines 16–23 commented out)
- Why fragile: The distribution ID and domain name outputs are commented out in prod, but are actively used in the strapi env. GitHub Actions workflows that need to invalidate the prod CloudFront distribution cannot retrieve the ID via `terraform output` without modifying the code.
- Safe modification: Uncomment the CDN outputs in `envs/frontend/prod/output.tf`.

**Dual startup scripts create confusion about which is actually used:**
- Files: `envs/strapi/startup_exact.sh`, `envs/strapi/startup.sh.tmpl`
- Why fragile: `main.tf` line 232 references `startup_exact.sh` directly (not the template). The template (`startup.sh.tmpl`) uses proper variable injection but is unused. Any change to the startup process must be made in two places or will silently diverge.
- Safe modification: Delete `startup_exact.sh`. Change `main.tf` to reference `startup.sh.tmpl` via `templatefile()`. Ensure `jenkins_ssh_public_key` is populated in `terraform.tfvars`.

---

## Missing Critical Features

**No CloudWatch alarms or monitoring:**
- Problem: There are no CloudWatch alarm resources, SNS topics, or log group resources anywhere in the repository.
- Blocks: Operators cannot be automatically alerted to EC2 CPU spikes, disk exhaustion, ECR push failures, or CloudFront 5xx error rate increases.
- Files: All envs — `envs/strapi/`, `envs/frontend/prod/`, `envs/frontend/staging/`

**No Route 53 DNS management:**
- Problem: Domains (`www.flydmair.com`, `staging.flydmair.com`, `strapi-cdn.dmair.net`) are referenced in tfvars but there are no `aws_route53_record` resources. DNS must be managed manually or out-of-band.
- Blocks: DNS changes cannot be tracked or audited in Terraform state. Certificate validation records have no automated lifecycle.
- Files: `envs/frontend/prod/terraform.tfvars`, `envs/frontend/staging/terraform.tfvars`, `envs/strapi/terraform.tfvars`

**No RDS — MySQL runs inside Docker on EC2:**
- Problem: `envs/strapi/ENV_VARS_GUIDE.md` confirms the database runs as a Docker container on the same EC2 instance. There is no RDS or Aurora resource.
- Blocks: No automated backups, point-in-time recovery, Multi-AZ failover, or storage autoscaling. A disk failure on the single t3.small instance loses all Strapi data.
- Files: `envs/strapi/` (no database module present)

**No WAF attached to CloudFront distributions:**
- Problem: None of the `aws_cloudfront_distribution` resources in `modules/cloudfront/main.tf` include a `web_acl_id`. The production frontend and Strapi CDN are unprotected from common web attacks and DDoS.
- Files: `modules/cloudfront/main.tf`

---

## Test Coverage Gaps

**No Terraform tests of any kind:**
- What's not tested: Module input validation (beyond ECR's single `validation` block), resource naming conventions, output values, policy template rendering, security group rule correctness.
- Files: All modules under `modules/` — no `.tftest.hcl` or `tests/` directories exist.
- Risk: Incorrect template variable names in `policies/*.tpl` produce malformed JSON silently at `terraform apply` time. Module interface changes break all callers with no compile-time check.
- Priority: High — the policy templates especially (`policies/s3_rw.tpl`, `policies/ecr_push.tpl`, etc.) have no validation that the rendered JSON is valid IAM.

---

*Concerns audit: 2026-05-20*
