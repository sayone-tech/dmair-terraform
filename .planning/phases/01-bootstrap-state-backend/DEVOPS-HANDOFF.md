# Phase 1 — DevOps Handoff

**Date assembled:** 2026-05-21
**Branch:** `feature/aws-deployment`
**Scope:** Phase 1 Bootstrap State Backend — `use_lockfile = true` migration across the bootstrap stack and all three live stacks, plus required-Terraform-version pin.

This is the consolidated DevOps-side runbook. It links to the per-plan runbooks and lists the exact sequence to apply against AWS once code review is signed off.

---

## Why this is code-only (and what that means)

Per the user's direction on 2026-05-21, all six plans of Phase 1 shipped as **code-only commits** on `feature/aws-deployment`. **No AWS-side command was run** during code execution — `terraform init`, `terraform apply`, `terraform plan`, and the `aws s3api` captures are all deferred to DevOps so the team can review the diff before any live infra is touched.

The "live-infra-is-sacred" invariant — `terraform plan` on every live stack must report `No changes` after every refactor commit — is preserved because the only code changes are:

- A new greenfield `bootstrap/` stack (no existing state, no resources created — only IMPORTs of the already-extant `dmair-terraform-prod` S3 bucket).
- Backend-config and Terraform-CLI-version pins on the three live `envs/*` stacks (`use_lockfile` is an internal state-locking mechanism; `required_version` is a CLI floor — neither affects any managed AWS resource).

None of these become active until DevOps runs `terraform init -reconfigure` and a fresh `terraform plan`.

---

## Sequence to apply (must be done in order)

### Step 1 — Plan 01-01: Live-state snapshot

Read [01-01-DEVOPS-RUNBOOK.md](./01-01-DEVOPS-RUNBOOK.md).

Requirements:
- Terraform CLI `>= 1.10` on PATH. (Workstation user already has 1.15.3; verify your own.)
- An AWS named profile `dmair` in `~/.aws/credentials` with at minimum **read** perms (`s3api Get*`, `sts:GetCallerIdentity`, `dynamodb describe-table`) on `dmair-terraform-prod`. The existing `dmair-view` IAM user has all of these.

Action:
1. Run the 8 `aws s3api`/`dynamodb`/`sts` commands listed in the runbook.
2. Fill in [01-LIVE-STATE-SNAPSHOT.md](./01-LIVE-STATE-SNAPSHOT.md) — paste each command's output into the matching code block.
3. Complete the HCL Translation Decisions table at the bottom.
4. Commit: `docs(BOOTSTRAP-01): capture live state of dmair-terraform-prod`.
5. Update [01-01-SUMMARY.md](./01-01-SUMMARY.md): change status from `code-only-complete` to `complete`, fill the DevOps results section.

### Step 2 — Plan 01-02: Apply the bootstrap stack

Read [01-02-PLAN.md](./01-02-PLAN.md) and [01-02-SUMMARY.md](./01-02-SUMMARY.md).

Requirements:
- A write-capable `[dmair]` profile resolved to an IAM identity with `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on `arn:aws:s3:::dmair-terraform-prod` and `arn:aws:s3:::dmair-terraform-prod/*`, plus `sts:GetCallerIdentity`. (`dmair-view` is not sufficient from here forward — `use_lockfile = true` writes a `.tflock` object to the state bucket during plan/apply.)

Action:
1. Open `bootstrap/main.tf`. Replace every `TODO_DEVOPS_FROM_SNAPSHOT` marker with the literal value from [01-LIVE-STATE-SNAPSHOT.md §HCL Translation Decisions](./01-LIVE-STATE-SNAPSHOT.md#hcl-translation-decisions).
2. `cd bootstrap && terraform init` — generates `bootstrap/.terraform.lock.hcl`. Commit: `chore(bootstrap): add terraform.lock.hcl from init`.
3. `terraform plan` — expected: `Plan: 0 to add, 4 to import, 0 to change, 0 to destroy.`
   - If any `to change` is non-zero on the imported resources: STOP. The HCL doesn't mirror live AWS. Re-check the snapshot capture against bootstrap/main.tf field-by-field.
4. `terraform apply` — answer yes. 4 imports succeed, 0 creates.
5. `terraform plan` again — must report `No changes. Your infrastructure matches the configuration.`
6. **Separate atomic commit:** open `bootstrap/main.tf` and delete all four `import { to = ...; id = "..." }` blocks. Run `terraform fmt`. Then `terraform plan` — must STILL report `No changes`. Commit: `chore(bootstrap): remove import blocks after successful adoption`.

### Step 3 — Plans 01-03 / 01-04 / 01-05: Live-stack rewires

Read [01-03-SUMMARY.md](./01-03-SUMMARY.md), [01-04-SUMMARY.md](./01-04-SUMMARY.md), [01-05-SUMMARY.md](./01-05-SUMMARY.md).

For each of `envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging`, **in that order per D-11** (strapi is the riskiest target — longest apply, EC2 with `prevent_destroy=true`; if the rewire mechanism breaks, it surfaces here first):

1. `cd envs/<env> && terraform init -reconfigure`
   - Expected: `Successfully configured the backend "s3"!`.
   - **Critical:** if Terraform prompts `Do you want to copy existing state to the new backend? (yes/no)`, answer **NO** and STOP. The migrate-state prompt should not appear (Pitfall 5 / D-12). Investigate `.terraform/` cache before retrying.
2. `terraform plan`
   - Expected: `No changes. Your infrastructure matches the configuration.`
   - **If anything else appears, STOP.** Revert the offending commit (each is independently revertable — see commit table below). Do not commit anything new until live infra is fully reconciled.

Commits already in place (DevOps does NOT re-commit unless reverting):

| Stack | backend.tf commit | providers.tf commit |
|---|---|---|
| `envs/strapi`            | `d3967bb` | `588703b` |
| `envs/frontend/prod`     | `27c4b11` | `65fbc6c` |
| `envs/frontend/staging`  | `9bb2345` | `b932911` |

### Step 4 — Plan 01-06: BOOTSTRAP-03 lock-contention proof

Read [01-06-DEVOPS-RUNBOOK.md](./01-06-DEVOPS-RUNBOOK.md) and [VERIFICATION.md](./VERIFICATION.md).

Action:
1. Two-terminal experiment against `envs/strapi`: terminal A holds `terraform apply` at the prompt; terminal B prints `Acquiring state lock. This may take a few moments...` and blocks.
2. Third-terminal `aws s3 ls s3://dmair-terraform-prod/strapi/` during and after the held apply — `.tflock` sentinel appears, then disappears.
3. Answer `no` to both apply prompts. Live infra is unchanged.
4. Fill in every `TODO_DEVOPS:` block in [VERIFICATION.md](./VERIFICATION.md) with pasted output / screenshots.
5. Check all four Phase Exit boxes; set top-line Outcome to PASS.
6. Commit: `docs(BOOTSTRAP-03): record concurrent-lock verification evidence`.
7. Run `/gsd-transition` (orchestrator will mark Phase 1 complete and route to Phase 2).

---

## Files reviewable in this PR

```
bootstrap/                                   (new)
├── backend.tf                               (10 lines; S3 backend at bootstrap/terraform.tfstate, use_lockfile = true)
├── providers.tf                             (16 lines; required_version = "~> 1.15", aws 5.91.0, hardcoded provider)
└── main.tf                                  (74 lines; 4 resources + 4 import blocks with TODO_DEVOPS markers)

envs/strapi/backend.tf                       (+1 line: use_lockfile = true)
envs/strapi/providers.tf                     (+1 line: required_version = "~> 1.15")
envs/frontend/prod/backend.tf                (+1 line: use_lockfile = true)
envs/frontend/prod/providers.tf              (+1 line: required_version = "~> 1.15")
envs/frontend/staging/backend.tf             (+1 line: use_lockfile = true)
envs/frontend/staging/providers.tf           (+1 line: required_version = "~> 1.15")

.planning/phases/01-bootstrap-state-backend/
├── 01-01-DEVOPS-RUNBOOK.md                  (new — 8 capture commands + translation rules)
├── 01-LIVE-STATE-SNAPSHOT.md                (new — fillable capture template)
├── 01-01-SUMMARY.md                         (new — code-only completion note)
├── 01-02-SUMMARY.md                         (new)
├── 01-03-SUMMARY.md                         (new)
├── 01-04-SUMMARY.md                         (new)
├── 01-05-SUMMARY.md                         (new)
├── 01-06-DEVOPS-RUNBOOK.md                  (new — two-terminal procedure)
├── 01-06-SUMMARY.md                         (new)
├── VERIFICATION.md                          (new — fillable evidence template)
└── DEVOPS-HANDOFF.md                        (this file)
```

`terraform fmt -check` passes on all `.tf` files.

---

## Rollback / safety

Every step above is reversible:

- Steps 3 (live-stack rewires): each `use_lockfile` and `required_version` edit is its own atomic commit. Revert any single commit, run `terraform init -reconfigure`, and the stack is back to its pre-Phase-1 state. (`use_lockfile`'s actual `.tflock` sentinel cleans itself up on the next non-locking apply.)
- Step 2 (bootstrap apply): `terraform state rm` each of the four imported resources and delete the `bootstrap/` directory. The bucket itself is untouched — the import only adopted state, it never created or modified the bucket.
- Step 1 (snapshot): pure documentation; no rollback needed.

If something is unclear, contact: the engineer who landed `feature/aws-deployment`.
