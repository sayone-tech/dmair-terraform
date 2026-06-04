# Phase 9 Seed — Terraform Refactor + State Backend

**Source:** Cross-repo planning continuation from `dmair-backend` v1.3 milestone (see
`bere-creator/dmair-backend:.planning/ROADMAP.md` Phase 9 row and `deployment/staging/STAGING-DEPLOYMENT.md`).
**Purpose:** Capture the six reality-vs-plan conflicts surfaced when we compared the
dmair-backend Phase 9 plan (written against a clean slate) to what actually lives in
this repo. The Phase 9 discussion / plan should resolve every one of these before
any `terraform apply` runs.

---

## What's actually in this repo today (snapshot 2026-05-20)

**Layout:**

```
modules/             # 11 reusable modules — already exist
  ec2, ecr, eip, iam-policy, iam-role, iam-user, s3,
  secrets_manager, sg, cloudfront, cloudfront-function
envs/                # NOT live/ — current naming
  strapi/                       # Strapi CMS, production, on EC2
  frontend/staging/             # staging.flydmair.com (frontend SPA)
  frontend/prod/                # www.flydmair.com, flydmair.com
policies/            # reusable IAM policy templates (*.tpl)
```

**State backend:**
- S3 bucket: `dmair-terraform-prod`
- Region: `us-west-2`
- Profile: `dmair`
- Keys: `strapi/terraform.tfstate`, `frontend/staging/terraform.tfstate`, `frontend/prod/terraform.tfstate`
- DynamoDB lock table: **NOT wired** in any backend.tf (README mentions `terraform-state-lock` but no code declares or uses it)

**Live resources (NOT a "company website" — multiple components):**
- `envs/strapi` — EC2 `t3.small` (Ubuntu 22.04) + Elastic IP, ECR, S3+CloudFront media,
  Dockerized MySQL on the same EC2, Secrets Manager. `lifecycle { prevent_destroy = true }` on EC2.
  DNS: `cms.flydmair.com`, `strapi-cdn.flydmair.com`.
- `envs/frontend/prod` — S3 + CloudFront with URL-rewriting CloudFront Function.
  DNS: `www.flydmair.com`, `flydmair.com`.
- `envs/frontend/staging` — S3 + CloudFront with basic-auth + URL-rewriting CloudFront Functions.
  DNS: **`staging.flydmair.com`** ← collides with the dmair-backend Caddy target.

---

## The six conflicts the Phase 9 plan must resolve

### Conflict 1: Region mismatch
- Existing infra (Strapi + frontend prod + frontend staging): **`us-west-2`**.
- `dmair-backend/deployment/staging/STAGING-DEPLOYMENT.md` §1: **`us-east-1`**.
- EC2 `prevent_destroy = true` blocks a destroy/recreate.
- **Decision needed:** keep dmair backend staging in `us-west-2` to share the account /
  state bucket, or stand it up in `us-east-1` as a parallel region (and probably account)
  for blast-radius isolation. STAGING-DEPLOYMENT.md is a draft, not an ADR — it can move.

### Conflict 2: `staging.flydmair.com` is already taken
- It currently points at `envs/frontend/staging`'s CloudFront distribution.
- STAGING-DEPLOYMENT.md §1 plans for the backend Caddy to acquire a Let's Encrypt cert
  for `staging.flydmair.com`, which requires the A-record to point at the backend's
  Elastic IP — directly contradicting the frontend staging assignment.
- **Decision needed:** rename the backend target (e.g. `staging-api.flydmair.com`,
  `backend-staging.flydmair.com`), or migrate the frontend staging to a different name.

### Conflict 3: Folder rename `envs/` → `live/<project>/<environment>/`
- ROADMAP Phase 9 success criterion 1 mandates the new structure: `modules/` +
  `live/<project>/<environment>/` with reserved `live/dmair/` slots.
- Current `envs/strapi` and `envs/frontend/{staging,prod}` would become
  `live/runway-one/strapi`, `live/runway-one/frontend-staging`, `live/runway-one/frontend-prod`
  (or similar project-keyed naming).
- This is destructive-looking over LIVE state. Mitigation: `moved { from = ... to = ... }`
  blocks per resource address; the exit criterion is `terraform plan` reports
  **"No changes"** for every existing stack after the rename.
- **Risk:** state-key path also changes (`strapi/terraform.tfstate` →
  `live/runway-one/strapi/terraform.tfstate`). Either keep the existing state keys
  (rename the folders only) or do `terraform state mv` / re-init to relocate.
- **Decision needed:** project-key naming (`dmair-cms`? `runway-one`? `flydmair`?) and
  whether to relocate state keys or keep them at their current paths.

### Conflict 4: State backend bootstrap is half-done
- Phase 9 success criterion 3 says "S3 remote-state bucket and DynamoDB lock table
  are provisioned (via `bootstrap/`)".
- Reality: bucket `dmair-terraform-prod` exists and is in use; no DynamoDB lock table
  is wired into any backend.tf; no `bootstrap/` directory exists describing the
  bucket itself.
- **Decision needed:** (a) add a `bootstrap/` stack that declares the existing bucket
  via `terraform import` + adds the missing DynamoDB lock table, then wire
  `dynamodb_table = "..."` into every backend.tf; or (b) treat the existing bucket as
  hand-managed and only `bootstrap/` the lock table.

### Conflict 5: ROADMAP's "company-website production stack" framing is wrong
- ROADMAP Phase 9 success criterion 2 says zero-change plan on "the live
  company-website production stack" — singular.
- Reality: **three** live stacks (`strapi`, `frontend/prod`, `frontend/staging`),
  none of which is a generic "company website" — Strapi is a CMS backing the site.
- **Decision needed:** rewrite the success criterion to cover all three live stacks
  with zero-change plans, not just one.

### Conflict 6: AWS account topology + OIDC policy scoping
- AWS profile is `dmair` for all three stacks — looks single-account.
- Phase 10's "tag/prefix-scoped Terraform OIDC permissions policy" (CICD-02) needs to
  know: is `dmair-backend` infra deploying into the same account as Strapi + frontend?
  If yes, the OIDC role's resource scoping has to exclude existing `cms-*` /
  `frontend-*` resources, not just include `dmair-staging-*`.
- **Decision needed:** confirm single-account topology; decide on a resource-tagging
  scheme (`App=dmair-backend` vs the existing `App=dmair`) so the OIDC policy can
  scope cleanly.

---

## Recommended Phase 9 plan shape (input to discuss-phase)

A draft of what the plan might look like after the discussion resolves the six conflicts:

1. **Bootstrap stack** (`bootstrap/`)
   - `terraform import` the existing `dmair-terraform-prod` bucket
   - Add DynamoDB lock table `dmair-terraform-locks`
   - Output: lock-table name for downstream backend.tf wiring

2. **Wire DynamoDB locking into every existing backend.tf**
   - Add `dynamodb_table = "dmair-terraform-locks"` to `envs/strapi/backend.tf`,
     `envs/frontend/staging/backend.tf`, `envs/frontend/prod/backend.tf`
   - `terraform init -reconfigure` each stack; verify plans are still zero-change

3. **Folder rename `envs/` → `live/`** (one stack at a time, zero-change-plan-gated)
   - Use `git mv` + `moved {}` blocks
   - For each stack: `terraform plan` must report "No changes"
   - If state keys are relocated, do `terraform state mv` and re-init

4. **Reserve `live/dmair/staging` slot** (empty for now — Phase 10 fills it)

5. **Update README** to match the new layout and document the bootstrap stack

**Exit criterion (Phase 9 done):**
- `terraform plan` in **every** live stack reports "No changes"
- DynamoDB lock table is in use by every backend
- `live/dmair/staging` directory exists with at minimum a `README.md` placeholder
- `bootstrap/` documents the state backend itself

---

## Things to confirm with the operator before drafting `discuss-phase`

- Region decision (Conflict 1)
- Backend staging DNS name (Conflict 2)
- Project-keyed folder naming under `live/` (Conflict 3)
- Whether to relocate state keys or keep them at current paths (Conflict 3)
- Single-account topology + tagging scheme (Conflict 6)

Once those are answered, the rest of the Phase 9 plan is mechanical.
