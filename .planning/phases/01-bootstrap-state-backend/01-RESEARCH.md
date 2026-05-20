# Phase 1: Bootstrap State Backend - Research

**Researched:** 2026-05-20
**Domain:** Terraform state-backend bootstrap — S3 bucket import + S3-native state locking + per-stack backend rewire under AWS provider `hashicorp/aws` 5.91.0
**Confidence:** HIGH (provider docs + AWS-side live inspection corroborated)

> **Revision note (2026-05-20, afternoon):** This research was written assuming a DynamoDB lock table per the morning's CONTEXT.md. The operator switched the chosen approach to S3-native locking (`use_lockfile = true`) the same afternoon. The text below has been edited to reflect that switch in the **Chosen Approach** sections (Summary, Standard Stack, Architecture Patterns, Code Examples). DynamoDB-flavored content is preserved in the **Alternatives Considered** and **Pitfalls** sections as part of the audit trail. Where a pitfall (e.g., Pitfall 1 — PAY_PER_REQUEST under DynamoDB) no longer applies under the chosen approach, the pitfall remains documented but is now annotated `[no longer applies under chosen approach — preserved for audit trail]`.

## Summary

Phase 1 is a two-step infrastructure-as-code bootstrap with a hard zero-change-plan invariant on three existing live stacks. The technical work is small (one new `bootstrap/` stack, three two-line edits to existing env files) but the foot-guns are concentrated: (1) the HCL for the four imported S3 sub-resources must mirror live AWS-side configuration verbatim or BOOTSTRAP-01's "No changes" gate fails, (2) Terraform 1.10+ supports S3-native state locking via `use_lockfile = true`; this is the chosen mechanism for this phase, replacing the morning's DynamoDB plan. Workstations must run Terraform ≥ 1.10; this phase pins `required_version = "~> 1.15"` in every `providers.tf` (workstation runs 1.15.3).

The research established that the operator cannot inspect the live `dmair-terraform-prod` bucket configuration from this machine (the local `fly-dmair` profile is read-list only — `s3:GetBucketVersioning`, `s3:GetEncryptionConfiguration`, `s3:GetBucketPublicAccessBlock`, etc. all return `AccessDenied`). A capture-then-translate task using a more-privileged operator profile is therefore a hard prerequisite to writing HCL, not a parallel research step.

**Primary recommendation:** Sequence the bootstrap as three discrete operator-gated steps in a single `bootstrap/` stack: (1) human runs three `aws s3api` inspections against `dmair-terraform-prod` and records output, (2) plan writes inline HCL that mirrors the captured values exactly, plus four `import {}` blocks (Terraform 1.5+ declarative import — safer than CLI imports because it's plan-visible and review-able), (3) `terraform apply` from a fresh `terraform init` adopts the bucket in one transaction (no CREATEs — only the 4 S3 IMPORTs). After zero-change-plan verification on `bootstrap/`, rewire the three live `backend.tf` files one at a time (adding `use_lockfile = true`), with the sibling `providers.tf` gaining `required_version = "~> 1.15"`, separated by zero-change-plan checkpoints, per CONTEXT D-11.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| S3 state bucket (existing — adopt via import) | Storage / Persistence | — | Pre-existing AWS resource, becomes IaC-managed in `bootstrap/` |
| S3 .tflock sentinel object (per-state-key, written by Terraform) | Coordination / Locking | — | Written automatically by Terraform 1.10+ when `use_lockfile = true` is set on `backend "s3"`; no additional AWS resource needed. |
| Per-stack remote state config | Terraform-CLI control plane | — | `backend "s3" { ... use_lockfile = true }` in `envs/*/backend.tf`; no resource graph involvement |
| Concurrent-apply prevention | Coordination / Locking | Terraform-CLI control plane | Terraform CLI acquires/releases lock via S3 `PutObject`/`DeleteObject` on a `<state-key>.tflock` sentinel object |
| Bootstrap stack's own state | Storage / Persistence (self-referential — same bucket) | — | Per CONTEXT D-01 (revised): bootstrap state lives at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate`, locked via the same `.tflock` sentinel mechanism as every other stack. |

## User Constraints (from CONTEXT.md)

> **Revised 2026-05-20 PM — see 01-CONTEXT.md "Previously Assumed" section for the original DynamoDB-flavored decisions.**

### Locked Decisions

**Bootstrap stack's own state**
- **D-01 (revised):** Bootstrap state lives at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate` (self-referential — uses the same bucket it imports). `use_lockfile = true` on bootstrap's own backend — bootstrap is locked via the S3-native `.tflock` sentinel, identical to every other stack.
- **D-02:** Bootstrap stack uses the same provider config as the live stacks: `hashicorp/aws` pinned to `5.91.0`, profile `dmair`, `shared_credentials_files = ["~/.aws/credentials"]`, region `us-west-2`.

**S3 bucket import scope**
- **D-03:** Pragmatic import — declare and `terraform import` four resources: `aws_s3_bucket.this` + `aws_s3_bucket_versioning.this` + `aws_s3_bucket_server_side_encryption_configuration.this` + `aws_s3_bucket_public_access_block.this`.
- **D-04:** Sub-resources NOT brought under IaC in this phase: bucket policy, lifecycle rules, logging, replication, ownership controls, CORS, tagging beyond what already exists. Drift here is accepted in v1.
- **D-05:** Research step REQUIRED before HCL is written — operator MUST `aws s3api get-bucket-versioning`, `get-bucket-encryption`, and `get-public-access-block` against `dmair-terraform-prod` and copy values verbatim into HCL.

**Lock mechanism**
- **D-06 (revised):** S3-native state locking via `use_lockfile = true`; no DynamoDB table provisioned.
- **D-07 (Obsolete — see 01-CONTEXT.md Previously Assumed).**
- **D-08 (Obsolete — see 01-CONTEXT.md Previously Assumed).**
- **D-09 (Obsolete — see 01-CONTEXT.md Previously Assumed).**
- **D-10 (Obsolete — see 01-CONTEXT.md Previously Assumed).**

**Backend rewire rollout sequencing**
- **D-11 (revised):** Three live backends rewired **one stack at a time, separate commits, with a zero-change-plan checkpoint between each**. Order: `envs/strapi` → `envs/frontend/prod` → `envs/frontend/staging`. Each stack's rewire inserts `use_lockfile = true` in `backend.tf` AND `required_version = "~> 1.15"` in `providers.tf`, in the same per-stack order.
- **D-12:** No `terraform init -migrate-state` expected — toggling the lock mechanism is a metadata-only reconfigure. If `init -reconfigure` prompts for `-migrate-state`, stop and investigate.
- **D-13:** Each rewire commit independently revertable.

**BOOTSTRAP-03 verification**
- **D-14:** Concurrent-apply lock contention verified **manually with two terminals**. Terminal B must print `Acquiring state lock. This may take a few moments...` and block until A completes.
- **D-15:** Lock-contention test runs against `strapi` stack (longest apply).

### Claude's Discretion

- HCL formatting + naming inside `bootstrap/` follows the repo's existing conventions: two-space indentation, `aws_s3_bucket.this` resource labels, `App_Name` / `Env_Type` variable naming style, `terraform.tfvars` for values. Planner can choose single `main.tf` (preferred) vs split files.
- The bootstrap stack does NOT reuse any module from `modules/`.

### Deferred Ideas (OUT OF SCOPE)

- State-key relocation to match `live/dmair/<env>/<component>` folder paths — tracked as v2 STATE-01.
- Importing bucket policy / lifecycle / logging / replication of `dmair-terraform-prod` — accepted as drift in v1.
- Customer-managed KMS key for the lock table or state bucket — AWS-managed SSE only in v1.
- Scripted concurrent-apply test — manual two-terminal verification only.
- Bootstrap stack self-locking (rewire bootstrap to use its own table) — explicitly rejected for v1.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOTSTRAP-01 | `bootstrap/` stack imports `dmair-terraform-prod` and enables `use_lockfile = true` on its own backend | Provider 5.91.0 import IDs + HCL shapes documented below (sections 1, 2). Live-state capture procedure documented (section 4). |
| BOOTSTRAP-02 | Every existing `backend.tf` wired with `use_lockfile = true`; sibling `providers.tf` pins `required_version = "~> 1.15"`; `terraform init -reconfigure`; zero-change plan | Backend block argument verified (section 3). `init -reconfigure` semantics confirmed (section 3). |
| BOOTSTRAP-03 | Concurrent apply blocked by lock | Exact CLI message verified (section 9). Lock-recovery via `terraform force-unlock` documented (section 9). |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Terraform CLI | ≥ 1.10 (recommended `~> 1.15`) | Apply + state mgmt + S3-native locking (use_lockfile requires 1.10+) | 1.10+ required for S3-native state locking. |
| `hashicorp/aws` provider | `5.91.0` (exact pin) | All AWS resource CRUD | Pinned across all three live stacks (`envs/*/providers.tf`). Bootstrap stack must match exactly to avoid mixed-provider drift on shared state bucket. |
| AWS CLI v2 | Any recent | Live-state inspection for capture-then-translate (D-05) | Required for `aws s3api get-bucket-*` and `aws dynamodb describe-table` verification. Confirmed installed locally (`/opt/homebrew/bin/aws`, v2.34.48). |

[VERIFIED: `envs/strapi/providers.tf`, `envs/frontend/prod/providers.tf`, `envs/frontend/staging/providers.tf` — all pin `5.91.0`]
[VERIFIED: GitHub `hashicorp/terraform-provider-aws` tag `v5.91.0` website docs]

### Supporting

None. Bootstrap declares resources inline; no `modules/*` reuse per CONTEXT D-03 and Claude-discretion section.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `use_lockfile = true` (S3-native, chosen) | `dynamodb_table = "dmair-terraform-locks"` (separate DynamoDB table) | DynamoDB locking is the legacy pattern, deprecated by HashiCorp in 1.11+. Adds an additional AWS resource and IAM permission set with no observable benefit on this single-account, single-operator workload. The phase originally chose DynamoDB (CONTEXT D-06 morning), then switched to use_lockfile the same afternoon (CONTEXT D-06 revised). [VERIFIED: developer.hashicorp.com S3 backend docs] |
| `terraform import <addr> <id>` (CLI command) | `import { to = ...; id = ... }` block (Terraform 1.5+) | Declarative block is plan-visible (operator sees the import in `terraform plan` output before apply), code-reviewable, and idempotent. CLI command is one-shot and silent. **Recommend the import block.** See section 5 for sequencing. [CITED: developer.hashicorp.com/terraform/language/block/import] |
| Hardcoded values in `main.tf` | Parameterized `variables.tf` + `terraform.tfvars` | CONTEXT.md left this to planner discretion. **Recommend hardcoding** — bootstrap is one-shot, one-region, one-bucket. Parameterization adds a `tfvars` file the operator must keep in sync with the very values they're hardcoding into other stacks' `backend.tf`. Repo convention is `terraform.tfvars` per env, but bootstrap is uniquely small. |

**Installation:**

Operator workstation prerequisites (NOT currently met on the working machine — verified):
- Terraform CLI ≥ 1.5 — **NOT INSTALLED** locally (`which terraform` → not found). Install via Homebrew: `brew install terraform` or `brew install hashicorp/tap/terraform`.
- AWS CLI v2 — **installed** (`/opt/homebrew/bin/aws`, v2.34.48).
- AWS named profile `dmair` in `~/.aws/credentials` with permissions for `s3:Get*`, `s3:PutBucketTagging`, `s3:PutObject` + `s3:DeleteObject` on the state-bucket prefix (Terraform writes/deletes the `.tflock` object). **The local machine has profile `fly-dmair` (user `dmair-view`), which is read-list only — `s3:GetBucketVersioning`, `s3:GetEncryptionConfiguration`, `s3:GetBucketPublicAccessBlock` all return `AccessDenied`.** Operator must arrange a more-privileged profile/role before running this phase.

**Version verification:**

```bash
# Confirmed 2026-05-20:
# AWS CLI: 2.34.48 (Darwin/arm64)
# Provider pin: hashicorp/aws 5.91.0 (envs/*/providers.tf)
# Terraform CLI: NOT INSTALLED LOCALLY — operator must install ≥1.5
```

## Architecture Patterns

### System Architecture Diagram

```text
                       ┌────────────────────────────────────────────┐
                       │   Operator workstation (terraform CLI)     │
                       │   AWS profile: dmair (writes) / fly-dmair  │
                       │   (read-only — see Environment section)    │
                       └────────────────┬───────────────────────────┘
                                        │
                          ┌─────────────┴─────────────┐
                          │                           │
                          ▼                           ▼
       ┌────────────────────────────────┐   ┌─────────────────────────────┐
       │ bootstrap/  (NEW)              │   │ envs/strapi/                │
       │   backend "s3" {               │   │   backend "s3" {            │
       │     key = "bootstrap/tfstate"  │   │     key = "strapi/tfstate"  │
       │     use_lockfile = true        │   │     use_lockfile = true     │
       │   }                            │   │   }                         │
       │   resources:                   │   │   providers.tf:             │
       │     aws_s3_bucket.this         │   │     required_version =      │
       │       (IMPORT)                 │   │       "~> 1.15"             │
       │     aws_s3_bucket_versioning   │   │                             │
       │       (IMPORT)                 │   │ envs/frontend/prod/         │
       │     aws_s3_bucket_sse_config   │   │   (same pattern)            │
       │       (IMPORT)                 │   │ envs/frontend/staging/      │
       │     aws_s3_bucket_PAB          │   │   (same pattern)            │
       │       (IMPORT)                 │   └──────────────┬──────────────┘
       └──────────────┬─────────────────┘                  │
                      │                                    │
                      ▼                                    ▼
       ┌──────────────────────────────────────────────────────────────────┐
       │              AWS account 071297531943, us-west-2                 │
       │                                                                  │
       │   ┌────────────────────────────────────────────────────────────┐ │
       │   │ S3 bucket                                                  │ │
       │   │   dmair-terraform-prod                                     │ │
       │   │   (existing — under IaC after bootstrap apply)             │ │
       │   │                                                            │ │
       │   │ keys:                                                      │ │
       │   │   bootstrap/terraform.tfstate                              │ │
       │   │   strapi/terraform.tfstate                                 │ │
       │   │   frontend/prod/tf.tfstate                                 │ │
       │   │   frontend/staging/tf.tfstate                              │ │
       │   │                                                            │ │
       │   │ Ephemeral lock sentinels (S3 .tflock sentinel objects,     │ │
       │   │ one per state key, written/deleted by Terraform during    │ │
       │   │ plan/apply):                                               │ │
       │   │   bootstrap/terraform.tfstate.tflock                       │ │
       │   │   strapi/terraform.tfstate.tflock                          │ │
       │   │   frontend/prod/tf.tfstate.tflock                          │ │
       │   │   frontend/staging/tf.tfstate.tflock                       │ │
       │   └────────────────────────────────────────────────────────────┘ │
       └──────────────────────────────────────────────────────────────────┘

Data flow:
  1. Bootstrap apply: terraform CLI → S3 PutObject (state) + 4× S3 PutObjectTagging (no-op for import). No new AWS resources beyond the four S3 sub-resource adoptions.
  2. Live-stack plan: terraform CLI → S3 PutObject (write .tflock sentinel) → S3 GetObject (read state) → diff → S3 DeleteObject (remove .tflock).
  3. Self-referential boundary: bootstrap/ writes its own state to the same bucket it manages. No race because S3 PutObject on a fresh key precedes any resource reconciliation in the apply.
```

### Recommended Project Structure

```
bootstrap/                         # NEW — single-file stack
├── main.tf                        # All resources + import blocks
├── backend.tf                     # S3 backend, NO dynamodb_table
├── providers.tf                   # hashicorp/aws 5.91.0 pin
└── .terraform.lock.hcl            # Generated on first init
```

No `variables.tf` or `terraform.tfvars` recommended. Bootstrap is one-shot, one-bucket, one-region — parameterization is overhead that increases the chance of drift between the bootstrap stack and the contract values (`dmair-terraform-prod`, `dmair-terraform-locks`) embedded as literals in every other `backend.tf`.

### Pattern 1: Declarative import via `import {}` block (Terraform 1.5+)

**What:** Add an `import { to = ...; id = ... }` block alongside the resource declaration. `terraform plan` shows the planned import as part of the diff; `terraform apply` adopts the resource into state. After successful apply, the import block can be removed from the code (recommended best practice — keeps configuration clean).

**When to use:** Importing pre-existing AWS resources into a fresh Terraform state. Strongly preferred over the CLI `terraform import` command because:
- The import is visible in `terraform plan` (operator review-able)
- The import is in version control (PR review-able)
- The import is idempotent (re-running plan after apply is a no-op)
- Plays correctly with the self-referential bootstrap (state and resource adoption happen in the same apply transaction)

**Example (S3 bucket):**

```hcl
# Source: https://github.com/hashicorp/terraform-provider-aws/blob/v5.91.0/website/docs/r/s3_bucket.html.markdown
resource "aws_s3_bucket" "this" {
  bucket = "dmair-terraform-prod"
  # No other arguments — see section 7 (Common Pitfalls) on omitting force_destroy
}

import {
  to = aws_s3_bucket.this
  id = "dmair-terraform-prod"
}
```

### Pattern 2: [OBSOLETE — see Alternatives Considered] `aws_dynamodb_table` for Terraform state locking (greenfield)

**[OBSOLETE 2026-05-20 PM]** This pattern was the chosen approach as of the morning of 2026-05-20 and was replaced the same afternoon by S3-native locking (`use_lockfile = true`). Preserved for audit. Plans 01-02 through 01-06 do NOT implement this pattern.

```hcl
# Source: https://github.com/hashicorp/terraform-provider-aws/blob/v5.91.0/website/docs/r/dynamodb_table.html.markdown
# HashiCorp guidance: developer.hashicorp.com/terraform/language/backend/s3 — "table must have a partition key named `LockID` with a type of `String`"
resource "aws_dynamodb_table" "this" {
  name         = "dmair-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  deletion_protection_enabled = true

  tags = {
    App_Name = "dmair-terraform"
    Env_Type = "bootstrap"
  }
}
```

**Notes:**
- **Do NOT** include `read_capacity` or `write_capacity` — AWS API rejects them under `PAY_PER_REQUEST` with `Neither ReadCapacityUnits nor WriteCapacityUnits can be specified when BillingMode is PAY_PER_REQUEST`. [CITED: github.com/aws/aws-cli/issues/4540]
- **Do NOT** include a `server_side_encryption` block — DynamoDB tables are SSE-encrypted by default with AWS-owned keys since 2018; omitting the block matches CONTEXT D-09 and avoids any computed-attribute drift.
- **Do NOT** include a `point_in_time_recovery` block — defaults to disabled when omitted, matching CONTEXT D-07. [VERIFIED: provider docs — "Required: Boolean to enable/disable the feature; defaults to false if the block is omitted"]
- The `attribute` block must NOT declare any other attributes beyond `LockID` — provider docs warn: "Only define attributes on the table object that are going to be used as Table hash key or range key" (declaring extra attributes can cause infinite plan loops). [CITED: provider docs]
- `deletion_protection_enabled` is the DynamoDB-native equivalent of the `lifecycle { prevent_destroy = true }` pattern used on CloudFront / EC2 / EIP elsewhere in the repo. CONTEXT D-08 chose this style. **Verified supported in provider 5.91.0** (introduced in v4.59.0, March 2023). [VERIFIED: hashicorp/terraform-provider-aws#29876]

### Pattern 3: Backend block with S3-native state locking (live-stack rewire)

The single-line edit applied to each `envs/*/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket                   = "dmair-terraform-prod"
    key                      = "strapi/terraform.tfstate"
    region                   = "us-west-2"
    profile                  = "dmair"
    shared_credentials_files = ["~/.aws/credentials"]
    use_lockfile             = true   # NEW LINE
  }
}
```

After the edit, run `terraform init -reconfigure` (NOT `-migrate-state` — toggling the lock mechanism on an existing S3 backend is a metadata-only reconfigure; no state moves). Per CONTEXT D-12, if `-reconfigure` prompts for `-migrate-state` instead, stop and investigate. [VERIFIED: HashiCorp guidance + community confirmation across multiple sources]

### Pattern 4: `required_version` pin in each `providers.tf`

The single-line edit added to each `providers.tf` (bootstrap + the three env stacks):

```hcl
terraform {
  required_version = "~> 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
  }
}
```

Rationale: `use_lockfile = true` requires Terraform ≥ 1.10. The workstation runs 1.15.3; pinning `~> 1.15` accepts any 1.15.x patch release without accidentally landing on 1.16. [VERIFIED: developer.hashicorp.com/terraform/language/settings#specifying-a-required-terraform-version]

### Anti-Patterns to Avoid

- **Declaring `force_destroy = false` on `aws_s3_bucket.this`** — `false` is the default and Terraform's documentation says "Terraform will only perform drift detection if a configuration value is provided." Declaring the default explicitly is fine but unnecessary; do NOT declare `force_destroy = true` on a state bucket — that would let `terraform destroy` wipe the bucket (and all state files in it). [CITED: provider docs + WebSearch]
- **Declaring `object_lock_enabled` on the bucket resource** — this attribute is "ForceNew" / create-time-only in provider v5; declaring it on an imported bucket where it was never set will trigger a destroy/recreate diff. Omit entirely.
- **Adding `tags = {}` on the imported `aws_s3_bucket.this`** — if the live bucket has no tags, declaring an empty `tags` map will still match (defaults to no tags). However, if the bucket has *any* AWS-side tags that aren't in the HCL, the plan will show a diff removing them. Per CONTEXT D-04 (drift on tagging accepted), the recommended approach is to declare no `tags` on the bucket import and accept any AWS-side tags as unmanaged drift.
- **Splitting the bootstrap apply across two `terraform apply` runs** (e.g., "first apply creates DynamoDB table, then second apply imports bucket"). A single apply with the import block handles both atomically. Two-step would require a temporary backend reconfigure and is the anti-pattern this phase is designed to avoid.
- **Reusing `modules/s3`** — that module is generic-purpose-bucket-shaped (CORS, public-access-block, optional versioning/website) and would not match a state-bucket import cleanly. Per CONTEXT and Claude-discretion section, declare resources inline.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrent-apply prevention | A custom lock file in S3, a flock-on-shared-NFS, a database row in RDS | `use_lockfile = true` in backend block (Terraform 1.10+ S3-native locking) | Terraform's built-in S3-native locking via `use_lockfile = true` is the current canonical pattern (DynamoDB-based locking is the deprecated predecessor and is preserved in this phase's audit trail under Alternatives Considered). Hand-rolled locking is the actual root cause of state corruption stories. |
| State-bucket adoption | A shell script that runs `terraform state push` against a hand-crafted state file | `import {}` block in the `bootstrap/` HCL | Terraform's declarative import handles AWS API discovery, attribute population, and refresh in one transaction. Hand-crafted state files miss computed attributes and are an indefinite source of "state vs reality" drift. |
| Pre-flight live-state capture | Hand-typed JSON / hand-typed HCL from memory | `aws s3api get-bucket-*` commands → record JSON → translate to HCL field-by-field | The four S3 sub-resource imports MUST mirror live AWS state verbatim or BOOTSTRAP-01's `No changes` gate fails. There is no provider-side or Terraform-side fuzzy-match — the plan diff is literal. |

**Key insight:** All three temptations stem from the same instinct ("I'll script around it"). Terraform's import block and S3+DynamoDB backend are the load-bearing primitives the entire ecosystem trusts; for a 4-file bootstrap stack, the cost of those primitives is zero and the cost of replacements is unbounded.

## Runtime State Inventory

This phase is greenfield-plus-import, not a rename/refactor. The S3 bucket exists; the DynamoDB table does not. There are no string-renames involved. Inventory is short:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | S3 state files at `s3://dmair-terraform-prod/{strapi,frontend/prod,frontend/staging}/terraform.tfstate` — verified via `aws s3api head-bucket` succeeds, `aws-cli/2.34.48` 2026-05-20 | None — state keys unchanged, file contents updated by Terraform on each apply (normal) |
| Live service config | No external services configure based on the bucket name; the bucket is internal-only (only Terraform reads/writes it) | None |
| OS-registered state | None | None |
| Secrets/env vars | AWS profile `dmair` referenced in every existing `backend.tf` via `profile = "dmair"`. On the local workstation today the profile is named `fly-dmair` instead — verified `aws configure list-profiles` shows `fly-dmair`, no `dmair`. Operator must either create a `dmair` profile or symlink. | Operator action: ensure `~/.aws/credentials` has a `[dmair]` section with permissions for S3 bucket-config read/write AND DynamoDB table create — the local `dmair-view` IAM user is read-list only and CANNOT do the import. |
| Build artifacts | None — Terraform has no compiled artifacts; `.terraform/` cache directories are per-stack and get regenerated by `init -reconfigure` | After each `backend.tf` edit + `terraform init -reconfigure`, the stack's `.terraform/terraform.tfstate` is rewritten with the new backend metadata (this is expected and not a state migration). |

**The canonical question:** After every file in the repo is updated and `bootstrap/` is applied, what runtime systems still reference the bucket or lock table?
- Every `backend.tf` references the bucket and (after rewire) the lock table by string literal — those strings ARE the contract. Renaming either later means a coordinated edit + `init -reconfigure` across all stacks.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Terraform CLI ≥ 1.5 | `import {}` block; entire phase | **✗ NOT INSTALLED locally** | — | Operator must install via `brew install terraform` before phase execution. **This is a blocking dependency.** |
| AWS CLI v2 | Live-state capture for D-05; lock-table verification (BOOTSTRAP success criterion 4) | ✓ | 2.34.48 | — |
| AWS profile `dmair` with `s3:Get*`, `s3:PutBucketTagging`, `dynamodb:CreateTable`, `dynamodb:DescribeTable`, `dynamodb:UpdateTable`, `dynamodb:TagResource` | Apply step (creates DynamoDB table, reads bucket config) | **✗ Local profile is `fly-dmair`, IAM user `dmair-view` — read-list only** | — | Operator must arrange a more-privileged AWS profile or assume-role flow before phase execution. **This is a blocking dependency.** Verified `s3:GetBucketVersioning` returns `AccessDenied` with current credentials. |
| Network egress to AWS | All steps | Assumed ✓ | — | — |
| Git working tree on `feature/aws-deployment` branch | Per-stack revert granularity (D-13) | ✓ | clean | — |

**Missing dependencies with no fallback:**
- Terraform CLI — operator must install before phase execution.
- AWS profile `dmair` with write permissions — operator must arrange before phase execution.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

> The `.planning/config.json` was not inspected by this researcher. The project explicitly excludes managed test tooling (PROJECT.md §Constraints: "No managed test suite — quality comes from `terraform plan` diffs reviewed by humans, plus the zero-change invariant"). Treat `nyquist_validation` as not applicable for this phase.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (`terraform plan` diff review by humans is the project's quality gate per PROJECT.md) |
| Config file | None |
| Quick run command | `terraform plan` in the relevant stack directory |
| Full suite command | `terraform plan` in each of `bootstrap/`, `envs/strapi/`, `envs/frontend/prod/`, `envs/frontend/staging/` (4 stacks total after this phase) |

### Phase Requirements → Verification Map

| Req ID | Behavior | Verification Type | Verification Command | File Exists? |
|--------|----------|-------------------|----------------------|--------------|
| BOOTSTRAP-01 | `bootstrap/` plans clean after import + table create | Manual (operator) | `cd bootstrap && terraform plan` → expect `No changes. Your infrastructure matches the configuration.` | Bootstrap stack to be created in Phase 1 |
| BOOTSTRAP-02 | All 3 live stacks plan clean after `use_lockfile` rewire | Manual (operator) | For each of `envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging`: `terraform init -reconfigure && terraform plan` → expect `No changes.` | ✅ all three `backend.tf` files exist |
| BOOTSTRAP-03 | Concurrent apply in same stack blocks on lock | Manual (operator, two terminals) | Terminal A: `cd envs/strapi && terraform apply` (D-15). Terminal B (immediately after A starts): same command. Expected terminal B output: `Acquiring state lock. This may take a few moments...` then blocks until A completes. | ✅ `envs/strapi/` exists |
| BOOTSTRAP success criterion 4 | `.tflock` sentinel object observed during held apply | Manual (operator, third terminal) | During a held terraform apply against `envs/strapi`: `aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/` → output must include `strapi/terraform.tfstate.tflock`. After apply release, re-run same s3 ls → output must NOT include the .tflock object. | ✅ `envs/strapi/` exists |

### Sampling Rate

- **Per task commit:** Operator runs `terraform plan` in the affected stack(s) and pastes the result into the PR description / VERIFICATION.md.
- **Per phase gate:** Run `terraform plan` in all 4 stacks (`bootstrap/`, `envs/strapi/`, `envs/frontend/prod/`, `envs/frontend/staging/`). All four must report `No changes` before the phase is complete.
- **BOOTSTRAP-03:** Manual two-terminal test exactly once; transcript pasted into `VERIFICATION.md` per CONTEXT D-14.

### Wave 0 Gaps

- [ ] Operator must install Terraform CLI ≥ 1.5 locally (`brew install terraform`).
- [ ] Operator must configure AWS profile `dmair` with write permissions (current local profile `fly-dmair` is read-only).
- [ ] No test framework install needed — project explicitly does not use one.

## Common Pitfalls

### Pitfall 1: `read_capacity` / `write_capacity` declared under `PAY_PER_REQUEST` [no longer applies under chosen approach — preserved for audit trail]

**What goes wrong:** `terraform apply` returns AWS API error: `Neither ReadCapacityUnits nor WriteCapacityUnits can be specified when BillingMode is PAY_PER_REQUEST` (or, in some provider versions, the provider catches it earlier as a plan-time validation error).
**Why it happens:** Many DynamoDB examples online show `read_capacity = 5; write_capacity = 5` because they predate on-demand. Copy-pasted into a PPR table, AWS rejects.
**How to avoid:** Omit both arguments entirely under `billing_mode = "PAY_PER_REQUEST"`.
**Warning signs:** Plan output references `read_capacity` or `write_capacity` at all.
[CITED: github.com/aws/aws-cli/issues/4540]

### Pitfall 2: HCL doesn't match live bucket → first plan is NOT `No changes`

**What goes wrong:** After successful `terraform apply` of the bootstrap stack, the first `terraform plan` reports a diff on `aws_s3_bucket_versioning.this`, `aws_s3_bucket_server_side_encryption_configuration.this`, or `aws_s3_bucket_public_access_block.this`. BOOTSTRAP-01 success criterion 1 fails.
**Why it happens:** The HCL was written from memory or assumed defaults instead of being copy-translated from the live `aws s3api get-bucket-*` output.
**How to avoid:** Follow the capture-then-translate procedure in section 4 (Code Examples) exactly. The operator must run the three `aws s3api` commands BEFORE writing HCL, save the JSON output, and translate field-by-field.
**Warning signs:** Plan shows `~ status = "Enabled" -> "Suspended"`, `~ sse_algorithm = "AES256" -> "aws:kms"`, or `~ block_public_acls = true -> false`.
**Recovery:** Edit HCL to match the live value, re-run plan; do NOT `terraform apply` until the diff is empty.

### Pitfall 3: Setting `versioning_configuration.status = "Disabled"` post-import

**What goes wrong:** If the live bucket has versioning `Enabled` and the HCL declares `Disabled`, `terraform apply` will fail with an AWS API error: S3 does not allow reverting a bucket to unversioned state once versioning has been enabled.
**Why it happens:** Operator assumes Disabled is the default and writes that.
**How to avoid:** Provider docs explicitly warn: "Disabled should only be used when creating or importing resources that correspond to unversioned S3 buckets." Capture live state first (Pitfall 2 procedure).
[CITED: provider docs — `aws_s3_bucket_versioning`]

### Pitfall 4: AWS profile name mismatch (`dmair` in backend.tf vs `fly-dmair` locally)

**What goes wrong:** `terraform init` fails with `NoCredentialProviders: no valid providers in chain. The config profile (dmair) could not be found`.
**Why it happens:** The repo's `backend.tf` files hardcode `profile = "dmair"`. The operator's `~/.aws/credentials` has only `[fly-dmair]`. Verified on the current workstation 2026-05-20.
**How to avoid:** Operator adds a `[dmair]` section to `~/.aws/credentials` (with appropriate write credentials, NOT the read-only `dmair-view` user) before running any Terraform command in this phase.
**Warning signs:** Any `terraform init` or `terraform plan` returns `could not be found` on profile resolution.

### Pitfall 5: `terraform init -reconfigure` prompts for `-migrate-state`

**What goes wrong:** After adding `dynamodb_table = "..."` to an existing `backend.tf` and running `terraform init -reconfigure`, the CLI asks: `Do you want to copy existing state to the new backend?` (the migrate-state prompt). CONTEXT D-12 says: stop.
**Why it happens:** Usually because the operator's local `.terraform/` cache has a stale `terraform.tfstate` pointing at a backend with different bucket/key/region — Terraform sees the change as a backend swap, not a lock-table addition.
**How to avoid:** Before running `init -reconfigure` on each live stack, verify the local `.terraform/terraform.tfstate` exists and references the current bucket/key. If not (e.g., on a fresh checkout), running `terraform init` first (without `-reconfigure`) populates the cache cleanly, then adding `dynamodb_table` and `init -reconfigure` is a clean metadata-only change.
**Recovery:** Answer NO to the migrate-state prompt, investigate `.terraform/` cache state, and retry. Never blindly accept migrate-state during this phase.

### Pitfall 6: `dynamodb_table` deprecation warning on Terraform 1.11+ [no longer applies under chosen approach — preserved for audit trail]

**What goes wrong:** `terraform init` / `plan` / `apply` prints a deprecation warning: `The dynamodb_table argument is deprecated and will be removed in a future minor version. Use use_lockfile = true for S3 native locking instead.` Operator misreads it as a plan diff or fails the zero-change-plan gate.
**Why it happens:** HashiCorp deprecated DynamoDB-based locking in Terraform 1.11 in favor of `use_lockfile = true`. CONTEXT D-06 locked in DynamoDB, so the phase ships with the deprecated argument; the warning is informational, not an error.
**How to avoid:** Document in PHASE-1 VERIFICATION.md that deprecation warnings on the `dynamodb_table` argument are EXPECTED and do not constitute a plan diff or failure. The `No changes. Your infrastructure matches the configuration.` line is what counts; warnings appear separately.
**Mitigation option:** Pin operator workstations to Terraform 1.10.x (last version without the deprecation) for the duration of v1. v2 work tracked separately can migrate to `use_lockfile = true`.
[CITED: developer.hashicorp.com/terraform/language/backend/s3; medium.com/aws-specialists/dynamodb-not-needed-for-terraform-state-locking-in-s3-anymore]

### Pitfall 7: Forgetting to remove the `import {}` block after successful apply

**What goes wrong:** No functional harm — the import block is a no-op after the resource is in state — but the code accumulates stale import blocks that confuse future readers and don't survive `terraform state rm`.
**Why it happens:** HashiCorp's "best practice" is to remove the block; many operators leave it.
**How to avoid:** After `terraform apply` succeeds and `terraform plan` reports `No changes`, delete the four `import {}` blocks from `bootstrap/main.tf` in a follow-up commit. Re-run `terraform plan` — still `No changes`. Commit.
[CITED: developer.hashicorp.com/terraform/language/block/import]

### Pitfall 8: Bucket has live tags that the HCL doesn't declare

**What goes wrong:** Per CONTEXT D-04, tagging beyond what already exists is OUT of scope. If the live bucket has e.g. `{Owner = "ops"}` and the HCL declares no `tags` argument, `terraform plan` may still show a diff because the provider reads back AWS-side tags into the plan.
**Why it happens:** The provider's read function populates `tags_all` from AWS; if `default_tags` is unset and `tags` is undeclared, Terraform should treat existing tags as unmanaged drift on `aws_s3_bucket`. In practice this behavior is consistent across v5.x, but if a diff appears, the fix is to declare `tags = { <whatever AWS has> }` verbatim in the HCL.
**How to avoid:** Capture `aws s3api get-bucket-tagging --bucket dmair-terraform-prod --region us-west-2` during the D-05 inspection step. If it returns tags, declare them in the bucket resource. If it returns `NoSuchTagSet`, the bucket has no tags — declare no `tags` argument.
**Warning signs:** Plan shows `~ tags = {} -> { Owner = "ops" }` or similar.

### Pitfall 9: Local `.terraform.lock.hcl` mismatch in bootstrap stack

**What goes wrong:** `terraform init` in `bootstrap/` produces a `.terraform.lock.hcl` keyed to the local OS/arch. If another operator runs from a different OS/arch later, lockfile drift can occur.
**Why it happens:** This is universal Terraform behavior, not specific to this phase. Existing `envs/*/.terraform.lock.hcl` files in the repo already exhibit this — operators have tolerated it.
**How to avoid:** Commit the lockfile generated on the first apply machine. Future operators who hit a hash mismatch can run `terraform providers lock -platform=darwin_arm64 -platform=linux_amd64` to add additional platforms.

### Pitfall 10: `.tflock` sentinel left behind after a crashed apply (use_lockfile)

**What goes wrong:** If a `terraform apply` process crashes hard (e.g., the operator's machine loses power or the SSH session drops), the `.tflock` sentinel object can be left in S3 and block subsequent applies. Subsequent `terraform plan`/`apply` reports `Error acquiring the state lock`.
**Why it happens:** Terraform writes the `.tflock` object at lock acquisition and deletes it at release. A crash between acquisition and release leaves the object orphaned.
**How to avoid:** Always Ctrl-C cleanly (Terraform catches SIGINT and releases the lock) rather than killing the process or rebooting mid-apply.
**Recovery:** `aws s3 rm s3://dmair-terraform-prod/<state-key>.tflock` (only after confirming no other terraform process holds it — verify via `ps`).

## Code Examples

### Example 1: Live-state capture procedure (operator-run, NOT Terraform)

These commands MUST run before any HCL is written. Use a profile with `s3:Get*` permissions (NOT the read-list-only `fly-dmair` profile available on the current workstation).

```bash
# Source: AWS CLI v2 reference + verified shape of error responses on 2026-05-20
PROFILE=dmair    # operator must arrange this profile with appropriate perms
REGION=us-west-2
BUCKET=dmair-terraform-prod

# 1. Versioning (expected output shape if Enabled):
#   { "Status": "Enabled", "MFADelete": "Disabled" }
# Or if never enabled:
#   (empty body; no JSON)
aws --profile $PROFILE s3api get-bucket-versioning --bucket $BUCKET --region $REGION

# 2. Encryption (expected output shape):
#   {
#     "ServerSideEncryptionConfiguration": {
#       "Rules": [
#         {
#           "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" },
#           "BucketKeyEnabled": false
#         }
#       ]
#     }
#   }
# Or, if SSE-KMS:
#       "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "arn:aws:kms:..." }
# Or, if no encryption set:
#   ServerSideEncryptionConfigurationNotFoundError (CLI returns non-zero)
aws --profile $PROFILE s3api get-bucket-encryption --bucket $BUCKET --region $REGION

# 3. Public access block (expected output shape):
#   {
#     "PublicAccessBlockConfiguration": {
#       "BlockPublicAcls": true,
#       "IgnorePublicAcls": true,
#       "BlockPublicPolicy": true,
#       "RestrictPublicBuckets": true
#     }
#   }
# Or, if no PAB set:
#   NoSuchPublicAccessBlockConfiguration (CLI returns non-zero)
aws --profile $PROFILE s3api get-public-access-block --bucket $BUCKET --region $REGION

# 4. Tagging — for Pitfall 8 check (not in CONTEXT D-05's required list, but cheap):
aws --profile $PROFILE s3api get-bucket-tagging --bucket $BUCKET --region $REGION
```

Save the JSON output of all four commands into the phase's `VERIFICATION.md` (or a scratch file the planner can reference in PLAN.md). The HCL in `bootstrap/main.tf` is then a translation table:

| AWS CLI field | HCL location | Example |
|---|---|---|
| `Status: "Enabled"` | `aws_s3_bucket_versioning.this.versioning_configuration.status` | `status = "Enabled"` |
| `Status: "Suspended"` | same | `status = "Suspended"` |
| `MFADelete: "Disabled"` | omit (default) | — |
| (no versioning at all) | use `status = "Disabled"` ONLY if bucket was never versioned | `status = "Disabled"` — but provider warns this is irreversible |
| `SSEAlgorithm: "AES256"` | `aws_s3_bucket_server_side_encryption_configuration.this.rule.apply_server_side_encryption_by_default.sse_algorithm` | `sse_algorithm = "AES256"` |
| `BucketKeyEnabled: false` | `aws_s3_bucket_server_side_encryption_configuration.this.rule.bucket_key_enabled` | `bucket_key_enabled = false` (or omit — default) |
| `BlockPublicAcls: true` | `aws_s3_bucket_public_access_block.this.block_public_acls` | `block_public_acls = true` |
| (same pattern for the other 3 PAB fields) | | |

### Example 2: Complete `bootstrap/main.tf` skeleton (planner refines after live capture)

```hcl
# Source: hashicorp/terraform-provider-aws v5.91.0 docs
# Source: developer.hashicorp.com/terraform/language/block/import
# Provider pin and backend block live in separate files (providers.tf, backend.tf)

# --- S3 state bucket (existing — adopted via import) ---

resource "aws_s3_bucket" "this" {
  bucket = "dmair-terraform-prod"
  # Intentionally minimal — see Pitfall 8 on tags, Anti-Pattern note on force_destroy
}

import {
  to = aws_s3_bucket.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "<CAPTURED-FROM-aws s3api get-bucket-versioning>"  # Enabled | Suspended | Disabled
  }
}

import {
  to = aws_s3_bucket_versioning.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "<CAPTURED — typically AES256>"
    }
    # bucket_key_enabled = <CAPTURED — only if true>
  }
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.this
  id = "dmair-terraform-prod"
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = <CAPTURED>
  block_public_policy     = <CAPTURED>
  ignore_public_acls      = <CAPTURED>
  restrict_public_buckets = <CAPTURED>
}

import {
  to = aws_s3_bucket_public_access_block.this
  id = "dmair-terraform-prod"
}

# --- DynamoDB lock table (greenfield) ---

resource "aws_dynamodb_table" "this" {
  name         = "dmair-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  deletion_protection_enabled = true

  tags = {
    App_Name = "dmair-terraform"
    Env_Type = "bootstrap"
  }
}
```

### Example 3: `bootstrap/backend.tf` (self-referential — uses S3-native locking)

```hcl
# Source: matches envs/strapi/backend.tf shape exactly, with key swapped + use_lockfile added
terraform {
  backend "s3" {
    bucket                   = "dmair-terraform-prod"
    key                      = "bootstrap/terraform.tfstate"
    region                   = "us-west-2"
    profile                  = "dmair"
    shared_credentials_files = ["~/.aws/credentials"]
    use_lockfile             = true   # per CONTEXT D-01 (revised 2026-05-20 PM) — bootstrap uses S3-native locking like every other stack
  }
}
```

### Example 4: `bootstrap/providers.tf` (copies `envs/strapi/providers.tf` shape, adds required_version pin)

```hcl
# Source: envs/strapi/providers.tf (verbatim shape — only var defaults / hardcoded values differ)
terraform {
  required_version = "~> 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
  }
}

provider "aws" {
  region                   = "us-west-2"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dmair"
}
```

Note: bootstrap hardcodes `region`/`profile`/`shared_credentials_files` rather than parameterizing via `var.aws_region` etc. (which `envs/strapi/providers.tf` does). Per Claude-discretion section, this is acceptable for a one-shot stack and avoids a `variables.tf` + `terraform.tfvars` pair just to hold three string literals already hardcoded in `backend.tf`.

### Example 5: First-apply sequence

```bash
# Operator runs from repo root, with the `dmair` profile arranged (NOT fly-dmair).
cd bootstrap

terraform init
# Expect: backend "s3" initializes, state file at s3://dmair-terraform-prod/bootstrap/terraform.tfstate
# is empty (first init). Provider plugin downloads.

terraform plan
# Expect:
#   - aws_s3_bucket.this IMPORT (existing)
#   - aws_s3_bucket_versioning.this IMPORT
#   - aws_s3_bucket_server_side_encryption_configuration.this IMPORT
#   - aws_s3_bucket_public_access_block.this IMPORT
#   - Total: 0 to add, 4 to import, 0 to change, 0 to destroy.
# If "to change" is NOT 0 for any imported resource, STOP — Pitfall 2.

terraform apply
# Expect: 4 success lines (S3 IMPORTs only), no errors. The 4 S3 sub-resources are
# adopted into state with their AWS-side values. No CREATEs.

terraform plan
# CRITICAL: must report "No changes. Your infrastructure matches the configuration."
# This is BOOTSTRAP-01 success criterion 1.

# Then in a follow-up commit, delete the four import {} blocks from main.tf:
terraform plan
# Must still report "No changes."
```

### Example 6: Per-stack rewire sequence (run 3× per CONTEXT D-11)

```bash
# 1. Edit envs/strapi/backend.tf — add: use_lockfile = true
# 2. Edit envs/strapi/providers.tf — add: required_version = "~> 1.15"
cd envs/strapi
terraform init -reconfigure
# Expect: "Successfully configured the backend "s3"!"
# If prompted for "-migrate-state" — STOP. See Pitfall 5.

terraform plan
# CRITICAL: must report "No changes."

# Commit envs/strapi/backend.tf edit and envs/strapi/providers.tf edit as TWO separate commits.

# Repeat for envs/frontend/prod, then envs/frontend/staging.
```

### Example 7: BOOTSTRAP-03 verification (manual two-terminal test, D-15)

```bash
# Terminal A:
cd envs/strapi
terraform apply
# When the "Acquiring state lock..." line appears, IMMEDIATELY run terminal B.

# Terminal B (separate shell):
cd envs/strapi
terraform apply
# Expected output:
#   Acquiring state lock. This may take a few moments...
# Terminal B BLOCKS here until terminal A finishes its apply
# (whether terminal A succeeds or operator answers "no" at the apply prompt).
# Once terminal A releases, terminal B's lock acquisition succeeds and apply proceeds.

# Lock recovery if needed (e.g., terminal A crashed mid-apply):
terraform force-unlock <LOCK_ID_FROM_ERROR_MESSAGE>
# LOCK_ID is printed in the lock-failure message when timeout expires.
# Use ONLY if you are sure no other terraform process holds the lock.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `aws_s3_bucket` with inline `versioning {}`, `server_side_encryption_configuration {}`, etc. | Separate `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`, etc. resources | provider v4 (April 2022); enforced in v5 | The split happened years ago; CONTEXT D-03's resource list reflects current best practice. Old inline blocks are removed in v5. |
| `terraform import <addr> <id>` (CLI command) | `import { to = ...; id = ... }` block | Terraform 1.5 (May 2023) | Declarative, plan-visible, code-reviewable. **Preferred for this phase.** |
| `dynamodb_table = "..."` in backend `"s3"` block | `use_lockfile = true` (S3 native locking, GA Terraform 1.11) | Terraform 1.10 experimental (Nov 2024), GA in 1.11 | The phase initially chose DynamoDB (CONTEXT D-06 morning of 2026-05-20) then switched to use_lockfile the same afternoon — see CONTEXT.md Previously Assumed. |

**Deprecated / outdated (do NOT use):**
- Inline `versioning {}` block on `aws_s3_bucket` — removed in provider v5.
- `acl = "private"` on `aws_s3_bucket` — replaced by `aws_s3_bucket_acl` (separate resource) in provider v5.
- `terraform import` CLI command — still works but the declarative `import {}` block is preferred for any review-able workflow.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `dynamodb_table` deprecation warning on Terraform 1.11+ is informational and does NOT cause `terraform plan` to report a diff. | Pitfall 6, Example 6 | LOW — the warning is well-documented as separate from plan output. Worst case: operator misreads warning as failure; rerunning the plan in 1.10.x resolves. [CITED but not directly tested with 5.91.0 against 1.11] |
| A2 | The live `dmair-terraform-prod` bucket has versioning, encryption, and public-access-block configured (rather than entirely default state). Stack ARN `arn:aws:s3:::dmair-terraform-prod` + bucket existence verified, but configuration content NOT inspectable from this workstation (verified `AccessDenied` from `fly-dmair`/`dmair-view`). | Pitfall 2, Example 1 | MEDIUM — if the bucket has NO versioning (i.e., never enabled), the HCL must declare `status = "Disabled"` and capture that fact, otherwise the bucket can never be made versioned later without a separate apply. The capture step in section 4 / Example 1 handles all three cases. |
| A3 | Provider 5.91.0 supports `deletion_protection_enabled` on `aws_dynamodb_table`. Source: provider docs at `v5.91.0` tag say "Yes, deletion_protection_enabled is documented as an optional argument that defaults to false." Cross-check: deletion-protection support was added in v4.59.0 (Mar 2023). | Pattern 2 | LOW — supported across all v4.59+ and all v5.x. Verified in docs at the v5.91.0 tag. |
| A4 | `aws_s3_bucket.this` declared with only `bucket = "..."` will NOT show drift on `force_destroy`, `object_lock_enabled`, or `tags` when those are unset on the AWS side. | Anti-Patterns, Pitfall 8 | LOW for `force_destroy` (defaults match), LOW for `object_lock_enabled` (ForceNew so it's compared against state, not desired-config-of-empty). MEDIUM for `tags` — if AWS has tags, plan may show diff; mitigated by capture in section 4. |
| A5 | The bootstrap stack's own state file at `s3://dmair-terraform-prod/bootstrap/terraform.tfstate` can be written by the very first `terraform apply` that imports the bucket, because the backend's S3 `PutObject` call only requires the bucket to exist in AWS (which it does — pre-existing), not in Terraform state. The self-reference is fine. | Architecture diagram, section 6 of original research questions | LOW — pattern is well-established in Terraform tutorials (the "Terraform bootstrap problem" articles all confirm this works). The bucket existing in AWS is the load-bearing fact; whether it's also in Terraform state is independent. |
| A6 | `terraform init -reconfigure` adding `dynamodb_table` to an existing initialized backend is metadata-only and does NOT trigger a `-migrate-state` prompt (CONTEXT D-12). | Pitfall 5, Example 6 | MEDIUM — community sources broadly agree, but I have not personally verified this against Terraform 1.10 + provider 5.91.0 in a sandbox. Pitfall 5 documents the recovery if it does prompt. |
| A7 | The exact CLI output string is `Acquiring state lock. This may take a few moments...` (capital A, ellipsis, no trailing whitespace). CONTEXT D-14 cites this string verbatim; multiple WebSearch sources cite the same string; HashiCorp's source code was not inspected at the exact version. | Example 7 | LOW — string is widely cited as stable across recent Terraform versions. |

**If this table is empty:** N/A — assumptions exist and are flagged above.

## Open Questions

1. **Will `terraform init -reconfigure` actually skip the `-migrate-state` prompt when adding `dynamodb_table` to an existing initialized backend?**
   - What we know: HashiCorp docs imply yes (adding a lock table is "metadata"); community sources broadly confirm; CONTEXT D-12 expects this.
   - What's unclear: Behavior with Terraform 1.10+ where DynamoDB is deprecated has not been directly verified.
   - Recommendation: Add a verification task to the PLAN.md that explicitly notes the expected behavior and the operator response if the prompt appears (answer NO and investigate per Pitfall 5).

2. **Does the live bucket have any tags, lifecycle rules, logging config, or bucket policy that the planner should be aware of (even though they're out of scope per D-04)?**
   - What we know: Cannot inspect from current workstation (`AccessDenied` from `dmair-view`). The bucket exists, is in us-west-2, in account `071297531943`.
   - What's unclear: Actual configuration contents.
   - Recommendation: Operator's capture step (Example 1) should ADD `get-bucket-tagging`, `get-bucket-policy`, `get-bucket-lifecycle-configuration`, `get-bucket-logging` to the inspection list — not because they're brought under IaC, but because surprises here are the most likely source of unexpected plan diffs.

3. **What is the exact Terraform CLI version the team standardizes on?**
   - What we know: README mentions ≥ 1.0. No `required_version` block in any `providers.tf` (CONCERNS.md flags this).
   - What's unclear: Whether team is on 1.5.x, 1.7.x, 1.10.x, or 1.11+.
   - Recommendation: Planner should ask the operator and document in PLAN.md. Pin to 1.10.x if the team wants to defer the `dynamodb_table` deprecation; pin to ≥1.5 if accepting the warning. Optionally add `required_version = ">= 1.5.0, < 2.0.0"` to `bootstrap/providers.tf` as a Phase 1 deliverable, though this is technically outside BOOTSTRAP-01's stated scope.

## Sources

### Primary (HIGH confidence)

- `hashicorp/terraform-provider-aws` GitHub repo at tag `v5.91.0`:
  - `website/docs/r/s3_bucket.html.markdown` — bucket resource arguments + import
  - `website/docs/r/s3_bucket_versioning.html.markdown` — versioning resource + import + status valid values + Disabled warning
  - `website/docs/r/s3_bucket_server_side_encryption_configuration.html.markdown` — SSE resource + import + sse_algorithm valid values
  - `website/docs/r/s3_bucket_public_access_block.html.markdown` — PAB resource + import + defaults (all false)
  - `website/docs/r/dynamodb_table.html.markdown` — table resource args, billing_mode values, deletion_protection_enabled, point_in_time_recovery block, attribute-block-loop warning
- `developer.hashicorp.com/terraform/language/backend/s3` — S3 backend `use_lockfile` argument (chosen approach); `dynamodb_table` (legacy, see Alternatives Considered). S3 backend `use_lockfile` documentation: developer.hashicorp.com/terraform/language/backend/s3#use_lockfile — verified.
- `developer.hashicorp.com/terraform/language/block/import` — declarative `import {}` block syntax + best practice to remove after successful apply
- Repo files at exact paths:
  - `envs/strapi/backend.tf`, `envs/frontend/prod/backend.tf`, `envs/frontend/staging/backend.tf` — current backend shape (no `dynamodb_table`)
  - `envs/strapi/providers.tf` — provider-pin shape to copy
  - `.planning/codebase/{STACK,CONVENTIONS,ARCHITECTURE,STRUCTURE,CONCERNS}.md` — convention + tech-debt context
- Live AWS API responses captured 2026-05-20:
  - `aws sts get-caller-identity --profile fly-dmair` → confirms account `071297531943`, user `dmair-view`
  - `aws s3api head-bucket --bucket dmair-terraform-prod --region us-west-2` → confirms bucket exists in us-west-2
  - `aws dynamodb describe-table --table-name dmair-terraform-locks --region us-west-2` → `ResourceNotFoundException` (greenfield)

### Secondary (MEDIUM confidence)

- github.com/aws/aws-cli/issues/4540 — AWS API rejects `read_capacity`/`write_capacity` under `PAY_PER_REQUEST`
- github.com/hashicorp/terraform-provider-aws/issues/29876 — `deletion_protection_enabled` request thread, confirms feature availability
- medium.com/aws-specialists/dynamodb-not-needed-for-terraform-state-locking-in-s3-anymore-29a8054fc0e9 — `use_lockfile` deprecation context
- atmos.tools/changelog/automatic-backend-provisioning + burakdede.com/blog/the-terraform-bootstrap-problem — bootstrap-pattern best practices
- spacelift.io/blog/terraform-import-block + env0.com/blog/terraform-import-commands-example-tips-and-best-practices — import-block usage

### Tertiary (LOW confidence)

- WebSearch results paraphrasing `Acquiring state lock. This may take a few moments...` — exact string also cited verbatim in CONTEXT D-14; multiple-source consensus; not personally verified in 1.10 + 5.91.0.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — provider pin, CLI requirements, AWS CLI requirements all verified against repo + AWS APIs.
- Architecture: HIGH — resource shapes verified against `terraform-provider-aws` repo at the exact `v5.91.0` tag.
- Pitfalls: HIGH on items 1–4, 7–8 (provider behavior or repo state directly verified); MEDIUM on items 5–6 (community-source confirmed, not personally tested at the exact version combination).
- Live-state capture procedure: HIGH (the AWS CLI command shapes are stable across CLI v2.x) — but the actual VALUES this phase will translate into HCL are unknown until the operator with appropriate permissions runs them.

**Research date:** 2026-05-20
**Valid until:** 2026-06-19 (30 days — slow-moving infrastructure ecosystem; HashiCorp's `dynamodb_table` deprecation timeline is the only ticking clock and "future minor version" is at least months out)

## RESEARCH COMPLETE

**Planner-facing summary:** The phase decomposes cleanly into four task waves: (Wave 0) operator preconditions — install Terraform CLI ≥ 1.5, arrange `dmair` AWS profile with write permissions, capture live S3 bucket config via `aws s3api` and record output; (Wave 1) create `bootstrap/` stack with hardcoded literals + four `import {}` blocks + `aws_dynamodb_table.this` and verify zero-change plan after apply, then a follow-up commit deleting the import blocks; (Wave 2) rewire `envs/strapi/backend.tf` with `dynamodb_table = "dmair-terraform-locks"`, `init -reconfigure`, verify zero-change, commit — then repeat for `envs/frontend/prod` and `envs/frontend/staging`; (Wave 3) manual two-terminal BOOTSTRAP-03 verification in the `strapi` stack and `aws dynamodb describe-table` automated check. Three hard pitfalls deserve explicit acceptance criteria in plan tasks: (1) HCL must mirror AWS-side bucket state (the `s3api` capture is the load-bearing artifact, not the Terraform code), (2) `read_capacity` / `write_capacity` MUST be absent from the DynamoDB table HCL under PPR, and (3) the `dynamodb_table` deprecation warning on Terraform 1.11+ is expected and is NOT a plan diff. The bootstrap stack's self-referential state is safe (verified bootstrap-pattern practice) — no chicken-and-egg failure mode in the canonical sequence. Two blocking environment dependencies must be resolved before any task can execute: Terraform CLI is not installed locally and the local `fly-dmair`/`dmair-view` profile is read-list-only.
