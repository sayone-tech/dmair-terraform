# Phase 1: Bootstrap State Backend - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

A new `bootstrap/` Terraform stack that (a) `terraform import`s the existing `dmair-terraform-prod` S3 state bucket into IaC and (b) enables S3-native state locking (`use_lockfile = true`) on bootstrap's own backend. Then `use_lockfile = true` is wired into every existing live backend (`envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging`) AND `required_version = "~> 1.15"` is pinned in each `providers.tf`, and each stack is `terraform init -reconfigure`'d. The phase is done when every live stack plans clean (`No changes`) and a two-terminal concurrent-apply demonstrates the second operator is blocked on the lock.

**Hard invariant:** Zero managed resource in any existing live stack may change. The S3 import in `bootstrap/` exists to put the state bucket under IaC without altering its current AWS-side configuration.

</domain>

<decisions>
## Implementation Decisions

> **Revision note (2026-05-20):** Decisions D-01, D-06 through D-15 were originally written around a DynamoDB lock table (dmair-terraform-locks). On 2026-05-20 the operator decided to use Terraform 1.10+'s S3-native state locking (`use_lockfile = true`) instead, which eliminates the lock table entirely. The original wording of each affected decision is preserved at the bottom of this file under "Previously Assumed" for audit purposes. The text below reflects the current chosen approach.

### Bootstrap stack's own state
- **D-01 (revised):** Bootstrap state lives at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate` (self-referential — uses the same bucket it imports). `use_lockfile = true` on the bootstrap backend itself — bootstrap is locked via the S3-native `.tflock` sentinel just like every other stack. Rationale: S3-native locking is built into Terraform 1.10+, so the lock table dance disappears entirely; bootstrap and the three live stacks all use the same single-line lock mechanism.
- **D-02:** Bootstrap stack uses the same provider config as the live stacks: `hashicorp/aws` pinned to `5.91.0`, profile `dmair`, `shared_credentials_files = ["~/.aws/credentials"]`, region `us-west-2`.

### S3 bucket import scope
- **D-03:** Pragmatic import — declare and `terraform import` four resources: `aws_s3_bucket.this` + `aws_s3_bucket_versioning.this` + `aws_s3_bucket_server_side_encryption_configuration.this` + `aws_s3_bucket_public_access_block.this`. These are the security-critical knobs for a Terraform state bucket.
- **D-04:** Sub-resources NOT brought under IaC in this phase: bucket policy, lifecycle rules, logging, replication, ownership controls, CORS, tagging beyond what already exists. They keep their current AWS-side state, unmanaged. Drift here is accepted in v1.
- **D-05:** Research step is REQUIRED before HCL is written — the researcher MUST `aws s3api get-bucket-versioning`, `get-bucket-encryption`, and `get-public-access-block` against `dmair-terraform-prod` and copy those values verbatim into the HCL so the first plan after import reports `No changes`. Any discrepancy between declared HCL and inspected state will surface as a non-zero plan diff and fail BOOTSTRAP-01's exit criterion.

### Lock mechanism (REPLACED — see Previously Assumed)
- **D-06 (revised):** S3-native state locking via `use_lockfile = true` in every `backend "s3" {}` block. No lock table is provisioned. The `.tflock` sentinel object is written by Terraform alongside the state object in the same S3 bucket during plan/apply.
- **D-07 / D-08 / D-09 / D-10 (obsolete):** Lock-table-specific knobs (PITR, deletion_protection, SSE choice, table tagging) no longer apply — there is no table.

### Backend rewire rollout sequencing
- **D-11 (revised):** Three live backends are rewired **one stack at a time, separate commits, with a zero-change-plan checkpoint between each**. Commit order: `envs/strapi` → `envs/frontend/prod` → `envs/frontend/staging`. For each: edit `backend.tf` to add `use_lockfile = true` AND edit `providers.tf` to add `required_version = "~> 1.15"`, run `terraform init -reconfigure`, run `terraform plan`, verify `No changes`, commit. Then proceed to next stack. Each stack gains TWO independent commits (backend.tf rewire + providers.tf pin), so per D-13 they remain independently revertable.
- **D-12:** No `terraform init -migrate-state` is expected — the lock-mechanism toggle is a metadata-only reconfigure, not a state migration. If `init -reconfigure` instead prompts for `-migrate-state`, stop and investigate before answering yes; this would indicate the operator's local `.terraform/` cache is out of sync.
- **D-13:** Each rewire commit is independently revertable. If stack #1 (`strapi`) somehow plans non-empty after the lock-mechanism wire, revert that single commit, leave the others untouched, and debug — the live-infra-is-sacred invariant is met by atomic per-stack rollback granularity.

### BOOTSTRAP-03 verification
- **D-14 (revised):** Concurrent-apply lock contention is verified **manually with two terminals** (no scripted CI test in this phase — no managed test suite per project constraint). Operator runs `terraform apply` in any one live stack from terminal A; immediately runs the same in terminal B; terminal B must print `Acquiring state lock. This may take a few moments...` and block until A completes. Verification artifact is a screenshot or transcript paste in the phase VERIFICATION.md. `aws s3 ls` of the bucket prefix during the held apply showing the `.tflock` object is the artifact for ROADMAP SC 4. The Acquiring state lock string itself is unchanged from the prior lock-table approach.
- **D-15:** The lock-contention test is run against the `strapi` stack specifically (its apply takes longest due to EC2 / EIP / IAM resources, giving the most time to observe contention in terminal B).

### Claude's Discretion
- HCL formatting + naming inside `bootstrap/` follows the repo's existing conventions: two-space indentation, `aws_s3_bucket.this` resource labels, `App_Name` / `Env_Type` variable naming style, `terraform.tfvars` for values. The planner can choose between a single `main.tf` (preferred — bootstrap is one-shot and tiny) or split files; CONTEXT.md does not lock that.
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
- `.planning/codebase/ARCHITECTURE.md` §State Backend Pattern — Current S3-only backend per stack (no state locking today; Phase 1 adds it), state-key paths
- `.planning/codebase/STRUCTURE.md` — Existing `envs/<x>/backend.tf` layout

### Existing live backends (the rewire targets)
- `envs/strapi/backend.tf` — Lock target #1 (rewire first, riskiest, used for BOOTSTRAP-03 verification)
- `envs/frontend/prod/backend.tf` — Lock target #2
- `envs/frontend/staging/backend.tf` — Lock target #3
- `envs/strapi/providers.tf` — Reference provider-block shape for `bootstrap/providers.tf`

### AWS provider docs (researcher must verify against 5.91.0)
- `aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block` — argument shapes + `terraform import` syntax
- `terraform { backend "s3" { use_lockfile = true } }` — S3-native state locking, Terraform 1.10+ feature (developer.hashicorp.com/terraform/language/backend/s3#use_lockfile)
- `terraform { required_version = "~> 1.15" }` — Terraform CLI version constraint (developer.hashicorp.com/terraform/language/settings#specifying-a-required-terraform-version)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`envs/strapi/providers.tf`** — Provider/version-pin block. Copy structure for `bootstrap/providers.tf`. Profile `dmair`, `shared_credentials_files = ["~/.aws/credentials"]`, region `us-west-2`.
- **`envs/*/backend.tf`** — Backend-block shape (bucket, key, region, profile, shared_credentials_files). Copy for `bootstrap/backend.tf`, swap `key` to `bootstrap/terraform.tfstate`.
- **`.terraform.lock.hcl` from any existing env** — Reference lockfile shape; bootstrap will generate its own on first init.

### Established Patterns
- **State-key paths in S3 are flat, not nested under env name.** Existing keys: `strapi/`, `frontend/prod/`, `frontend/staging/`. Bootstrap follows: `bootstrap/terraform.tfstate`.
- **`prevent_destroy` on load-bearing resources** (CloudFront `modules/cloudfront/main.tf:126`, EC2 `modules/ec2/main.tf:46`, EIP `modules/eip/main.tf:11`). The S3 state bucket itself is load-bearing for the new `.tflock` sentinel objects, but the sentinels themselves are ephemeral and self-managing — no analog of `deletion_protection_enabled` is needed under the S3-native locking approach.
- **Variable-driven config via `terraform.tfvars`** — every env stack ships a `terraform.tfvars`. Bootstrap likely ends up with a thin `terraform.tfvars` (region, profile, table name, bucket name) — planner decides whether to hardcode or parameterize.
- **No Registry modules; all module sources local.** Bootstrap declares resources inline; does not call any `modules/*`.

### Integration Points
- After `bootstrap/` is applied, every existing `backend.tf` gains a single new line: `use_lockfile = true`, and each `providers.tf` gains `required_version = "~> 1.15"`. No other change to existing stacks.
- The lock mechanism is built into Terraform 1.10+ — there is no cross-stack data source or string-literal contract. The `.tflock` sentinel object's key is derived automatically from the state key (`<state-key>.tflock`).

</code_context>

<specifics>
## Specific Ideas

- **Existing bucket properties are unknown today.** The first concrete research task in Phase 1 is `aws s3api get-bucket-versioning`, `get-bucket-encryption`, `get-public-access-block` against `dmair-terraform-prod`. Whatever those return becomes the HCL. Do not assume defaults.
- **README in CLAUDE.md/codebase notes a state-bucket-name mismatch** (`.planning/codebase/CONCERNS.md` flags it). Bootstrap is the right place to make the README authoritative — but the README update lives in Phase 2 (DOCS-01), not here. Phase 1 only touches IaC.
- **No DynamoDB resource at all.** The lock mechanism is S3-native (`use_lockfile = true`), so Terraform writes/deletes a `.tflock` sentinel object via `s3:PutObject` / `s3:DeleteObject` on the same prefix as the state object.

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

<previously_assumed>
## Previously Assumed (revised 2026-05-20)

The decisions below were drafted on 2026-05-20 (morning) and superseded later the same day by the switch to S3-native state locking. They are preserved for audit trail of why the original direction was chosen and why it was changed.

### Original D-01: bootstrap is unlocked
- Bootstrap state lives at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate`. No dynamodb_table on the bootstrap backend itself — it stays unlocked. Rationale: bootstrap is edited by one operator on rare occasions; matches the existing S3-only pattern; avoids a two-step "apply table, then rewire bootstrap to use it" dance.

### Original D-06: aws_dynamodb_table.terraform_locks
- name = "dmair-terraform-locks", hash key LockID (String), billing_mode = "PAY_PER_REQUEST". PPR is HashiCorp's recommended default for state locking; on this workload (handful of plan/apply runs per day) it costs effectively $0 vs $0.50+/mo for provisioned.

### Original D-07: point_in_time_recovery off
- Locks are ephemeral; stuck locks recovered with terraform force-unlock, not table restore. No backup cost.

### Original D-08: deletion_protection_enabled = true
- Extends existing prevent_destroy convention used on CloudFront/EC2/EIP — the lock table would be load-bearing.

### Original D-09: AWS-managed SSE for the lock table
- DynamoDB tables SSE-encrypted by default since 2018. No customer KMS key — keep blast radius small.

### Original D-10: Tagging App_Name="dmair-terraform", Env_Type="bootstrap"
- Matched project's existing tag-key casing convention.

### Original D-11: rewires insert dynamodb_table line
- Three live backends rewired one stack at a time, separate commits, with a zero-change-plan checkpoint between each. Commit order: envs/strapi → envs/frontend/prod → envs/frontend/staging. For each: edit backend.tf to add dynamodb_table = "dmair-terraform-locks", run terraform init -reconfigure, run terraform plan, verify No changes, commit. Single commit per stack.

### Original D-14: ROADMAP SC 4 verified by aws dynamodb describe-table
- aws dynamodb describe-table --table-name dmair-terraform-locks --region us-west-2 returning ACTIVE with LockID hash key was the artifact for ROADMAP SC 4.

### Why we switched (2026-05-20)
- Terraform 1.10 made S3-native state locking (`use_lockfile = true`) GA. It writes a `.tflock` sentinel object alongside the state object in the same S3 bucket, so it requires no additional AWS resource. No table to manage, no separate IAM permission set, no separate billing item, no separate "what if the table is deleted" risk. The workstation already runs Terraform 1.15.3, so the version floor is non-binding. The trade-off (loss of separate per-table IAM scoping) is irrelevant because the same operator profile already controls both the bucket and any lock mechanism.
</previously_assumed>
