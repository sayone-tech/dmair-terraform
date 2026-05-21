# Phase 2 — DevOps Handoff

**Date:** 2026-05-21
**Branch:** `feature/aws-deployment`
**Scope:** Move all three live stacks to `live/dmair/<env>/<component>/`, reserve the staging slot, rewrite root README.

This is the second code-only PR in the migration. Phase 1 (state backend) must be DevOps-applied before Phase 2 can be applied, because:
- Phase 2's hard gate is zero-change plan after the move. Without `use_lockfile = true` in place (Phase 1 deliverable), a concurrent operator mistake during the rename verification could corrupt state.

If Phase 1 is not yet applied: apply it first per [`../01-bootstrap-state-backend/DEVOPS-HANDOFF.md`](../01-bootstrap-state-backend/DEVOPS-HANDOFF.md), then come back here.

---

## What's in the diff

```
git log --oneline ec6dc95^..HEAD                       # commits in this phase
```

| Commit | What |
|---|---|
| `eb49d2b` | `refactor(REFACTOR-01): move strapi to live/dmair/prod/strapi/` |
| `ec6dc95` | `refactor(REFACTOR-01): move frontend/prod to live/dmair/prod/frontend/` |
| `5dbf19b` | `refactor(REFACTOR-01): move frontend/staging to live/dmair/staging/frontend/` |
| `7de5aaa` | `docs(REFACTOR-02): reserve live/dmair/staging/ slot for dmair-backend` |
| `e24dfe4` | `docs(DOCS-01): rewrite README around live/ layout and use_lockfile` |

---

## Sequence to apply

For each of the three moved stacks **in order** (strapi first — it's the riskiest because of `prevent_destroy = true` on EC2/EIP; if the move surfaces drift, it'll surface there):

### Step 1 — Strapi

```sh
cd live/dmair/prod/strapi
rm -rf .terraform/                  # OPTIONAL but recommended: drop the pre-move .terraform/ cache
terraform init -reconfigure         # must NOT prompt for migrate-state (state key is unchanged)
terraform plan                      # MUST report: No changes. Your infrastructure matches the configuration.
```

If `terraform plan` reports any diff, the rename has surfaced something. **Do not commit and do not apply.** Most likely causes:
1. A missed relative-path bump somewhere in main.tf. Re-grep: `grep -rn "\.\./\.\./modules/" .` (bare 2-up — there should be zero matches).
2. Stale `.terraform/` cache linked to the old path. Clear it and re-init.
3. A module call label was accidentally renamed (it shouldn't be — this PR keeps every label identical). Spot-check `git diff main..HEAD live/dmair/prod/strapi/main.tf` for any label changes.

### Step 2 — Frontend prod

```sh
cd live/dmair/prod/frontend
rm -rf .terraform/
terraform init -reconfigure
terraform plan                      # MUST report: No changes.
```

### Step 3 — Frontend staging

```sh
cd live/dmair/staging/frontend
rm -rf .terraform/
terraform init -reconfigure
terraform plan                      # MUST report: No changes.
```

### Step 4 — Phase-wide invariant check

```sh
# Bootstrap stack (Phase 1) should still plan clean.
cd bootstrap && terraform plan      # MUST report: No changes.

# All four stacks plan clean simultaneously.
```

### Step 5 — Fill VERIFICATION.md + transition

Open `.planning/phases/02-refactor-to-live-layout/VERIFICATION.md` and paste:
- `find live -type d` output (SC 1)
- Three `No changes` plan outputs (SC 2 — the hard gate)
- `aws s3 ls --recursive` showing the four state keys at unchanged paths (SC 3)
- README spot-check (SC 5)

Tick all four Phase Exit checkboxes and set Outcome = PASS. Commit:

```
docs(REFACTOR-03): record live/ layout verification evidence
```

Then run `/gsd-transition` to advance to Phase 3.

---

## Rollback

Every commit in this phase is independently revertable. To roll back a single stack:

```sh
git revert <stack-move-commit-sha>
# Then in the affected stack directory:
rm -rf .terraform/
terraform init -reconfigure
terraform plan      # should be No changes against the pre-revert state
```

To roll back the entire phase: `git revert` the five commits (three moves + staging placeholder + README rewrite) in reverse order, or `git reset --hard <pre-phase-2-sha>` if no other work has landed on the branch.

---

## What this phase does NOT do

- **Does not change any AWS-managed resource.** Pure filesystem reorg + relative-path bump. State keys are unchanged.
- **Does not introduce `moved {}` blocks.** No module call labels are renamed; resource addresses are stable.
- **Does not create `live/dmair/staging/backend/`.** That's Phase 3.
- **Does not touch `live/dmair/prod/`.** Prod EC2/EIP/CloudFront stay exactly as they were.
