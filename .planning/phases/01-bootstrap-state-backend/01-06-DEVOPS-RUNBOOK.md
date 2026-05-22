# Plan 01-06 — DevOps Runbook: Verify BOOTSTRAP-03 lock contention

**Status:** Code-only completion deferred this plan's two-terminal experiment to DevOps. This runbook is the procedure. The fillable evidence file is [VERIFICATION.md](./VERIFICATION.md).

---

## Prerequisites

All of plans 01-01 through 01-05 must be DevOps-applied first:
- Plan 01-01: live-state snapshot captured.
- Plan 01-02: `bootstrap/` applied, imports done, zero-change plan reported, import blocks removed in follow-up commit.
- Plan 01-03/04/05: each of `envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging` `init -reconfigure`'d and reports `No changes` on `terraform plan`.

This runbook is the LAST step before Phase 1 is complete.

---

## Two-terminal lock contention test (per D-15)

Run against `envs/strapi` (longest apply gives most observation time; D-15 specifies strapi).

**Terminal A:**

```sh
cd envs/strapi
terraform apply
```

Wait until terraform finishes refresh/plan and prints `Do you want to perform these actions? Enter a value:`. **DO NOT** answer the prompt — leave terminal A waiting. Terraform holds the S3 state lock for the entire duration of this prompt.

(If the stack truly has nothing to change, `terraform apply` may print `No changes.` and exit before you can switch terminals. In that case the lock is only held during the refresh phase — you need to be quick to start terminal B before refresh completes. Easier alternative: in terminal A run `terraform refresh` instead, which can be canceled with Ctrl-C to release the lock.)

**Terminal B (while A is paused at the prompt):**

```sh
cd envs/strapi
terraform apply
```

Expected within a few seconds:

```
Acquiring state lock. This may take a few moments...
```

Terminal B blocks at that message and does not progress.

**Terminal C (optional but recommended for ROADMAP SC 4):**

```sh
aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ --human-readable --summarize
```

Expected output: includes both `terraform.tfstate` (the state object) AND `terraform.tfstate.tflock` (the sentinel lock object). Capture this output.

---

## Cleanup (live-infra-is-sacred — DO NOT actually apply)

1. In **terminal A:** answer `no` (or hit Ctrl-C). Terminal A exits without changing any live infra; the lock releases.
2. **Terminal B** unblocks within seconds, runs its own refresh/plan, and reaches its own apply prompt. Answer `no` there too. Both terminals exit. Live infra is unchanged.
3. In **terminal C:** run the `aws s3 ls` command again. Expected: `terraform.tfstate.tflock` is gone; only `terraform.tfstate` remains. Capture this output.

If either terminal hangs after both prompts have been answered, recover with:
```sh
cd envs/strapi
terraform force-unlock <LOCK_ID>   # LOCK_ID is printed in the lock-failure message
```

---

## Failure paths

| Symptom | Diagnosis | Action |
|---|---|---|
| Terminal B proceeds straight to plan/apply without "Acquiring state lock" | `use_lockfile = true` not actually applied — likely `terraform init -reconfigure` not run after the plan-01-03 edit | Re-run `cd envs/strapi && terraform init -reconfigure` and retry. |
| Terminal B prints `Error acquiring the state lock` with a LOCK_ID and exits | Lock was held by a prior aborted apply | `terraform force-unlock <LOCK_ID>`, then retry from terminal A. |
| `aws s3 ls` shows no `.tflock` even during held apply | Wrong region or wrong bucket key | Verify `envs/strapi/backend.tf` key is `strapi/terraform.tfstate` and region is `us-west-2`. |

---

## Fill in VERIFICATION.md

For each `TODO_DEVOPS:` block in [VERIFICATION.md](./VERIFICATION.md):

1. **BOOTSTRAP-01 section** — paste the post-apply `No changes` output from `bootstrap/` (from plan 01-02 step 5) and the post-import-block-removal `No changes` output (from plan 01-02 step 6). Add the import-block-removal commit SHA.
2. **BOOTSTRAP-02 section** — paste the three `No changes` outputs from `envs/strapi`, `envs/frontend/prod`, `envs/frontend/staging`.
3. **BOOTSTRAP-03 section** — paste terminal B's "Acquiring state lock" output. Add the sign-off line.
4. **ROADMAP SC 4 section** — paste the `aws s3 ls` outputs from terminal C (during held apply showing `.tflock`, then after release showing no `.tflock`).
5. **Phase Exit** — check all four boxes once evidence is in place. Set the top-line **Outcome** to PASS.

Commit message:
```
docs(BOOTSTRAP-03): record concurrent-lock verification evidence
```

Then run `/gsd-transition` (the orchestrator will mark Phase 1 complete and route to Phase 2).
