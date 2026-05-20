# Phase 1: Bootstrap State Backend - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-20
**Phase:** 1-bootstrap-state-backend
**Areas discussed:** Bootstrap stack's own state, S3 bucket import scope, DynamoDB lock table shape, Backend rewire rollout sequencing

---

## Bootstrap stack's own state

| Option | Description | Selected |
|--------|-------------|----------|
| Self-referential S3, no lock on bootstrap | backend.tf points to `s3://dmair-terraform-prod` with key `bootstrap/terraform.tfstate`, no `dynamodb_table`. Bootstrap stays unlocked (edited rarely, by one operator). Simplest; matches existing S3-only pattern. | ✓ |
| Self-referential S3 + self-locking | Same S3 key, but after the table exists, add `dynamodb_table = "dmair-terraform-locks"` to bootstrap/backend.tf and re-init. Two-step apply. Cleanest end state. | |
| Local state, gitignored | `bootstrap/.terraform/terraform.tfstate` stays on the operator's laptop. Risky for cross-operator handoff. | |
| Local state, committed to repo | `terraform.tfstate` committed to git. Trivially recoverable but anti-pattern (sensitive output, merge conflicts). | |

**User's choice:** Self-referential S3, no lock on bootstrap
**Notes:** Matches the existing S3-only backend pattern already used by every live stack; bootstrap is touched rarely enough that single-operator-at-a-time is a safe assumption.

---

## S3 bucket import scope

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — import bucket shell only | Declare only `aws_s3_bucket.this` and import that one resource. Sub-resources keep current state, unmanaged. Fastest; lowest risk; cost is partial IaC. | |
| Full — import bucket + all sub-resources | Inspect bucket via `aws s3api` (versioning, encryption, public-access-block, lifecycle, policy) and declare matching resources. Full IaC; more imports; researcher must read current state first. | |
| Pragmatic — bucket + versioning + SSE + public_access_block only | Import bucket plus the three security-critical sub-resources. Skip lifecycle / policy / logging / replication. Middle ground. | ✓ |

**User's choice:** Pragmatic — bucket + versioning + SSE + public_access_block only
**Notes:** Researcher MUST inspect current bucket state via `aws s3api` before writing HCL so the post-import plan reports `No changes`. Bucket policy / lifecycle / logging stay as accepted drift in v1.

---

## DynamoDB lock table shape

### Billing mode

| Option | Description | Selected |
|--------|-------------|----------|
| PAY_PER_REQUEST (on-demand) | No capacity planning. ~$0 at this traffic level. HashiCorp's recommended default for lock tables. | ✓ |
| PROVISIONED 1 RCU / 1 WCU | Slightly cheaper at sustained traffic but pays minimum 24/7. Marginal savings not worth extra config. | |

**User's choice:** PAY_PER_REQUEST (on-demand)

### Point-in-time recovery (PITR)

| Option | Description | Selected |
|--------|-------------|----------|
| Off | Locks are ephemeral; stuck locks recovered with `terraform force-unlock`, not table restore. | ✓ |
| On | Continuous backups, 35-day restore window. Costs marginally more. | |

**User's choice:** Off

### Deletion protection

| Option | Description | Selected |
|--------|-------------|----------|
| On | `deletion_protection_enabled = true`. Matches the `prevent_destroy` pattern used on CloudFront / EC2 / EIP. Stops a `terraform destroy` in `bootstrap/` from nuking the load-bearing lock table. | ✓ |
| Off | Default. Bootstrap stack is rarely touched. | |

**User's choice:** On

**Notes (whole area):** SSE stays at AWS-managed default (DynamoDB tables are SSE-encrypted by default since 2018). No customer KMS key.

---

## Backend rewire rollout sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| One stack at a time, separate commits, verify-gate between | Commit order: strapi → init-reconfigure → verify zero-change → commit. Then frontend/prod, then frontend/staging. Three commits. Smallest blast radius; matches live-infra-is-sacred posture. | ✓ |
| All three in one commit, then init each | Single commit changes all three backend.tf files. Operator runs init -reconfigure + plan in each. Less granular rollback. | |
| Stage strapi first, then bundle the two frontends | Two commits: strapi alone (highest blast risk), then frontend/prod + frontend/staging together. Middle ground. | |

**User's choice:** One stack at a time, separate commits, verify-gate between
**Notes:** Stack order is fixed: strapi → frontend/prod → frontend/staging. Each rewire commit is independently revertable. `terraform init -reconfigure` is expected to NOT trigger `-migrate-state`; if it does, stop and investigate.

---

## Claude's Discretion

- HCL file split inside `bootstrap/` (single `main.tf` vs split) — planner decides.
- Whether bootstrap uses `terraform.tfvars` for the bucket / table name or hardcodes literals — planner decides; both fit existing convention.
- Resource label style (`aws_dynamodb_table.this` vs `.terraform_locks`) — planner picks; both are conventional.
- BOOTSTRAP-03 verification target stack (which live stack to use for the two-terminal lock-contention test) — defaulted to `strapi` in CONTEXT.md but planner may pick differently if a better candidate emerges during planning.

## Deferred Ideas

- **State-key relocation** to match `live/dmair/<env>/<component>` paths — v2 STATE-01 in REQUIREMENTS.md.
- **Importing bucket policy / lifecycle / logging / replication / ownership controls** of `dmair-terraform-prod` — accepted as drift in v1.
- **Customer-managed KMS key** for state bucket or lock table — AWS-managed SSE only in v1.
- **Scripted concurrent-apply test** — manual two-terminal verification only; project excludes managed test tooling per PROJECT.md.
- **Bootstrap stack self-locking** (rewiring bootstrap to use its own lock table) — explicitly rejected in v1.
