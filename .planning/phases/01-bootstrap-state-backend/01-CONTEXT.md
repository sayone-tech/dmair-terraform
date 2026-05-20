# Phase 1: Bootstrap State Backend - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

A new `bootstrap/` Terraform stack that (a) `terraform import`s the existing `dmair-terraform-prod` S3 state bucket into IaC and (b) provisions a new `dmair-terraform-locks` DynamoDB lock table in `us-west-2`. Then `dynamodb_table = "dmair-terraform-locks"` is wired into every existing live backend (`envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging`) and each stack is `terraform init -reconfigure`'d. The phase is done when every live stack plans clean (`No changes`) and a two-terminal concurrent-apply demonstrates the second operator is blocked on the lock.

**Hard invariant:** Zero managed resource in any existing live stack may change. The S3 import in `bootstrap/` exists to put the state bucket under IaC without altering its current AWS-side configuration.

</domain>

<decisions>
## Implementation Decisions

### Bootstrap stack's own state
- **D-01:** Bootstrap state lives at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate` (self-referential — uses the same bucket it imports). No `dynamodb_table` on the bootstrap backend itself — it stays unlocked. Rationale: bootstrap is edited by one operator on rare occasions; matches the existing S3-only pattern already used by the three live stacks; avoids a two-step "apply table, then rewire bootstrap to use it" dance.
- **D-02:** Bootstrap stack uses the same provider config as the live stacks: `hashicorp/aws` pinned to `5.91.0`, profile `dmair`, `shared_credentials_files = ["~/.aws/credentials"]`, region `us-west-2`.

### S3 bucket import scope
- **D-03:** Pragmatic import — declare and `terraform import` four resources: `aws_s3_bucket.this` + `aws_s3_bucket_versioning.this` + `aws_s3_bucket_server_side_encryption_configuration.this` + `aws_s3_bucket_public_access_block.this`. These are the security-critical knobs for a Terraform state bucket.
- **D-04:** Sub-resources NOT brought under IaC in this phase: bucket policy, lifecycle rules, logging, replication, ownership controls, CORS, tagging beyond what already exists. They keep their current AWS-side state, unmanaged. Drift here is accepted in v1.
- **D-05:** Research step is REQUIRED before HCL is written — the researcher MUST `aws s3api get-bucket-versioning`, `get-bucket-encryption`, and `get-public-access-block` against `dmair-terraform-prod` and copy those values verbatim into the HCL so the first plan after import reports `No changes`. Any discrepancy between declared HCL and inspected state will surface as a non-zero plan diff and fail BOOTSTRAP-01's exit criterion.

### DynamoDB lock table shape
- **D-06:** `aws_dynamodb_table.terraform_locks` — `name = "dmair-terraform-locks"`, hash key `LockID` (String), `billing_mode = "PAY_PER_REQUEST"`. PPR is HashiCorp's recommended default for state locking; on this workload (handful of plan/apply runs per day) it costs effectively $0 vs $0.50+/mo for provisioned.
- **D-07:** `point_in_time_recovery` is **off**. Locks are ephemeral; stuck locks are recovered with `terraform force-unlock`, not table restore. No backup cost.
- **D-08:** `deletion_protection_enabled = true`. Extends the existing `prevent_destroy` convention used on CloudFront / EC2 / EIP in this repo — the lock table is now a load-bearing dependency of every other stack; `terraform destroy` in `bootstrap/` must not be able to nuke it.
- **D-09:** Server-side encryption stays at the AWS-managed default (DynamoDB tables are SSE-encrypted by default since 2018). No customer KMS key — keeps blast radius small; can be revisited if a compliance requirement appears later.
- **D-10:** Tagging: minimum viable — `App_Name = "dmair-terraform"`, `Env_Type = "bootstrap"`. Matches the project's existing tag-key casing convention.

### Backend rewire rollout sequencing
- **D-11:** Three live backends are rewired **one stack at a time, separate commits, with a zero-change-plan checkpoint between each**. Commit order: `envs/strapi` → `envs/frontend/prod` → `envs/frontend/staging`. For each: edit `backend.tf` to add `dynamodb_table = "dmair-terraform-locks"`, run `terraform init -reconfigure`, run `terraform plan`, verify `No changes`, commit. Then proceed to next stack.
- **D-12:** No `terraform init -migrate-state` is expected — adding a lock table to an existing S3 backend is a metadata-only reconfigure, not a state migration. If `init -reconfigure` instead prompts for `-migrate-state`, stop and investigate before answering yes; this would indicate the operator's local `.terraform/` cache is out of sync.
- **D-13:** Each rewire commit is independently revertable. If stack #1 (`strapi`) somehow plans non-empty after the lock-table wire, revert that single commit, leave the other two untouched, and debug — the live-infra-is-sacred invariant is met by atomic per-stack rollback granularity.

### BOOTSTRAP-03 verification
- **D-14:** Concurrent-apply lock contention is verified **manually with two terminals** (no scripted CI test in this phase — no managed test suite per project constraint). Operator runs `terraform apply` in any one live stack from terminal A; immediately runs the same in terminal B; terminal B must print `Acquiring state lock. This may take a few moments...` and block until A completes. Verification artifact is a screenshot or transcript paste in the phase VERIFICATION.md.
- **D-15:** The lock-contention test is run against the `strapi` stack specifically (its apply takes longest due to EC2 / EIP / IAM resources, giving the most time to observe contention in terminal B).

### Claude's Discretion
- HCL formatting + naming inside `bootstrap/` follows the repo's existing conventions: two-space indentation, `aws_dynamodb_table.this` / `aws_s3_bucket.this` resource labels, `App_Name` / `Env_Type` variable naming style, `terraform.tfvars` for values. The planner can choose between a single `main.tf` (preferred — bootstrap is one-shot and tiny) or split files; CONTEXT.md does not lock that.
- The bootstrap stack does NOT need to reuse any module from `modules/`. The S3 module is generic-purpose-bucket-shaped and would not match a state-bucket import cleanly; inline resources keep BOOTSTRAP-01's import surface minimal and explicit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 1 — Phase boundary, success criteria (4 exit checks), dependency story
- `.planning/REQUIREMENTS.md` §Bootstrap — BOOTSTRAP-01, BOOTSTRAP-02, BOOTSTRAP-03 acceptance criteria
- `.planning/PROJECT.md` §Core Value — Live-infra-is-sacred invariant

### Codebase Map (existing intel)
- `.planning/codebase/STACK.md` — Provider pin (`hashicorp/aws` `5.91.0`), Terraform CLI ≥ 1.0, state-bucket name + keys, `dmair` AWS profile
- `.planning/codebase/CONVENTIONS.md` — Variable casing (`App_Name`, `Env_Type`), resource labels (`aws_*.this`), HCL formatting, two-space indent, `prevent_destroy` pattern
- `.planning/codebase/ARCHITECTURE.md` §State Backend Pattern — Current S3-only backend per stack, no DynamoDB lock, state-key paths
- `.planning/codebase/STRUCTURE.md` — Existing `envs/<x>/backend.tf` layout

### Existing live backends (the rewire targets)
- `envs/strapi/backend.tf` — Lock target #1 (rewire first, riskiest, used for BOOTSTRAP-03 verification)
- `envs/frontend/prod/backend.tf` — Lock target #2
- `envs/frontend/staging/backend.tf` — Lock target #3
- `envs/strapi/providers.tf` — Reference provider-block shape for `bootstrap/providers.tf`

### AWS provider docs (researcher must verify against 5.91.0)
- `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block` — argument shapes + `terraform import` syntax
- `aws_dynamodb_table` — `billing_mode`, `deletion_protection_enabled`, `point_in_time_recovery` blocks for provider 5.91.0
- `terraform { backend "s3" { dynamodb_table = ... } }` — backend block argument

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`envs/strapi/providers.tf`** — Provider/version-pin block. Copy structure for `bootstrap/providers.tf`. Profile `dmair`, `shared_credentials_files = ["~/.aws/credentials"]`, region `us-west-2`.
- **`envs/*/backend.tf`** — Backend-block shape (bucket, key, region, profile, shared_credentials_files). Copy for `bootstrap/backend.tf`, swap `key` to `bootstrap/terraform.tfstate`.
- **`.terraform.lock.hcl` from any existing env** — Reference lockfile shape; bootstrap will generate its own on first init.

### Established Patterns
- **State-key paths in S3 are flat, not nested under env name.** Existing keys: `strapi/`, `frontend/prod/`, `frontend/staging/`. Bootstrap follows: `bootstrap/terraform.tfstate`.
- **`prevent_destroy` on load-bearing resources** (CloudFront `modules/cloudfront/main.tf:126`, EC2 `modules/ec2/main.tf:46`, EIP `modules/eip/main.tf:11`). The DynamoDB lock table is now load-bearing — `deletion_protection_enabled = true` is the DynamoDB-native equivalent.
- **Variable-driven config via `terraform.tfvars`** — every env stack ships a `terraform.tfvars`. Bootstrap likely ends up with a thin `terraform.tfvars` (region, profile, table name, bucket name) — planner decides whether to hardcode or parameterize.
- **No Registry modules; all module sources local.** Bootstrap declares resources inline; does not call any `modules/*`.

### Integration Points
- After `bootstrap/` is applied, every existing `backend.tf` gains a single new line: `dynamodb_table = "dmair-terraform-locks"`. No other change to existing stacks.
- The lock table is referenced by string literal (`"dmair-terraform-locks"`), not by Terraform output — there is no cross-stack data source. The table name is a contract; if it ever needs to be renamed, every backend.tf gets edited and re-init'd in lockstep.

</code_context>

<specifics>
## Specific Ideas

- **Existing bucket properties are unknown today.** The first concrete research task in Phase 1 is `aws s3api get-bucket-versioning`, `get-bucket-encryption`, `get-public-access-block` against `dmair-terraform-prod`. Whatever those return becomes the HCL. Do not assume defaults.
- **README in CLAUDE.md/codebase notes a state-bucket-name mismatch** (`.planning/codebase/CONCERNS.md` flags it). Bootstrap is the right place to make the README authoritative — but the README update lives in Phase 2 (DOCS-01), not here. Phase 1 only touches IaC.
- **No DynamoDB GSI / TTL / streams** on the lock table. Just the LockID hash key. Terraform's state-locking protocol only uses GetItem / PutItem / DeleteItem on the primary key.

</specifics>

<deferred>
## Deferred Ideas

- **State-key relocation to match `live/dmair/<env>/<component>` folder paths** — tracked as v2 STATE-01 in REQUIREMENTS.md. Folder layout changes in Phase 2; state keys do not move (would require per-stack `terraform state mv`).
- **Importing bucket policy / lifecycle / logging / replication of `dmair-terraform-prod`** — out of scope for v1; accepted as drift between declared HCL and AWS-side state. Revisit if a compliance audit requires fuller IaC coverage.
- **Customer-managed KMS key for the lock table or state bucket** — AWS-managed SSE only in v1. Revisit if a compliance requirement appears.
- **Scripted concurrent-apply test** — manual two-terminal verification only in v1; the project explicitly excludes managed test tooling.
- **Bootstrap stack self-locking (rewire bootstrap to use its own table)** — explicitly rejected for v1 in favor of the simpler S3-only backend on bootstrap itself. Revisit only if multiple operators start editing bootstrap concurrently.

</deferred>

---

*Phase: 1-Bootstrap State Backend*
*Context gathered: 2026-05-20*
