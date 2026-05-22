# Phase 1: Bootstrap State Backend — Verification Evidence

**Status:** TEMPLATE — pending DevOps execution per [01-06-DEVOPS-RUNBOOK.md](./01-06-DEVOPS-RUNBOOK.md).

**Date:** _(YYYY-MM-DD)_
**Verifier:** _(DevOps name)_
**Outcome:** _PASS / FAIL — fill in after all four sections below have evidence_

---

## BOOTSTRAP-01 — `bootstrap/` stack imports `dmair-terraform-prod` + enables `use_lockfile` on bootstrap backend

### Evidence required

- Pasted `terraform plan` `No changes.` output from `bootstrap/` (after `terraform apply` with imports).
- Commit SHA for the bootstrap stack creation: `3ea3266` (`feat(BOOTSTRAP-01): bootstrap stack scaffold (code-only)`).
- Commit SHA for the post-apply import-block removal: _(DevOps fill in)_

### Pasted `terraform plan` output from bootstrap/

```text
TODO_DEVOPS: paste the final `Plan:` / `No changes. Your infrastructure matches the configuration.` line from `cd bootstrap && terraform plan` (run AFTER `terraform apply` adopted the 4 S3 sub-resources).
```

### Post-import-block-removal re-plan

```text
TODO_DEVOPS: paste the `No changes.` output after the import {} blocks were removed in a separate atomic commit.
```

---

## BOOTSTRAP-02 — All three live backends rewired to S3-native state locking

### Commit table (six independently-revertable commits per D-13)

| Stack | backend.tf commit | providers.tf commit |
|---|---|---|
| `envs/strapi`            | `d3967bb` `feat(BOOTSTRAP-02): enable use_lockfile on strapi backend`            | `588703b` `chore(strapi): pin required_version to ~> 1.15` |
| `envs/frontend/prod`     | `27c4b11` `feat(BOOTSTRAP-02): enable use_lockfile on frontend-prod backend`     | `65fbc6c` `chore(frontend/prod): pin required_version to ~> 1.15` |
| `envs/frontend/staging`  | `9bb2345` `feat(BOOTSTRAP-02): enable use_lockfile on frontend-staging backend`  | `b932911` `chore(frontend/staging): pin required_version to ~> 1.15` |

### Zero-change plan evidence (one per stack)

**envs/strapi:**
```text
TODO_DEVOPS: paste No-changes output from `cd envs/strapi && terraform plan`.
```

**envs/frontend/prod:**
```text
TODO_DEVOPS: paste No-changes output from `cd envs/frontend/prod && terraform plan`.
```

**envs/frontend/staging:**
```text
TODO_DEVOPS: paste No-changes output from `cd envs/frontend/staging && terraform plan`.
```

---

## BOOTSTRAP-03 — Concurrent apply blocked by S3-native lock

### Experiment (per D-15, against `envs/strapi`)

Setup: two terminals, both `cd envs/strapi`. Terminal A runs `terraform apply` and waits at the `Do you want to perform these actions?` prompt holding the state lock. Terminal B then runs `terraform apply` and must print `Acquiring state lock. This may take a few moments...` and block.

### Terminal B "Acquiring state lock" evidence

```text
TODO_DEVOPS: paste terminal B's full output (or screenshot path) showing:
  Acquiring state lock. This may take a few moments...
and the subsequent successful acquisition once terminal A released the lock.
```

### Sign-off

```text
TODO_DEVOPS: one-line confirmation along the lines of:
"Terminal B blocked on the S3 state lock for the duration that terminal A held it. Lock released and terminal B proceeded once terminal A exited. Both terminals answered `no` to the apply prompt — live-infra-is-sacred invariant preserved."
```

---

## ROADMAP Success Criterion 4 — `.tflock` sentinel observed during held apply

### `aws s3 ls` evidence — DURING held apply

```text
TODO_DEVOPS: paste output of:
  aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ --human-readable --summarize
captured from a third terminal WHILE terminal A is holding the lock at the apply prompt.
Expected: output contains both `terraform.tfstate` AND `terraform.tfstate.tflock`.
```

### `aws s3 ls` evidence — AFTER release

```text
TODO_DEVOPS: paste output of the same command captured AFTER terminal A exits.
Expected: `terraform.tfstate` only — `.tflock` is gone.
```

### Confirmation

```text
TODO_DEVOPS: one-line — "The `.tflock` sentinel appeared while terraform held the lock and disappeared within seconds of the apply being canceled."
```

---

## Phase Exit

Mark each criterion PASS or FAIL after evidence is filled in above. All four must be PASS for the phase to be complete.

- [ ] **BOOTSTRAP-01** — bootstrap stack adopts dmair-terraform-prod with zero-change plan (with AND without import blocks)
- [ ] **BOOTSTRAP-02** — all three live backends report zero-change plan after `init -reconfigure`
- [ ] **BOOTSTRAP-03** — observed lock contention between two concurrent `terraform apply` invocations
- [ ] **ROADMAP SC 4** — `.tflock` sentinel object observed in S3 during held apply and gone after release

When all four boxes are checked, this phase is complete. Commit this file with message:
`docs(BOOTSTRAP-03): record concurrent-lock verification evidence`

Then run `/gsd-transition` to advance to Phase 2.
