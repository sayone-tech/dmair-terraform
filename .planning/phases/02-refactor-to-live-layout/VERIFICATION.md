# Phase 2: Refactor to live/ Layout — Verification Evidence

**Status:** TEMPLATE — pending DevOps execution.

**Date:** _(YYYY-MM-DD)_
**Verifier:** _(DevOps name)_
**Outcome:** _PASS / FAIL_

---

## Success Criterion 1 — Directory tree

```sh
find live -type d
```

Expected to include (operator verifies):
- `live/dmair/strapi/prod/`
- `live/dmair/frontend/prod/`
- `live/dmair/frontend/staging/`
- `live/dmair/staging/` (the parent — with the placeholder README)

```sh
ls envs/
```

Expected: `No such file or directory` (envs/ removed).

```text
TODO_DEVOPS: paste `find live -type d` output here.
```

```text
TODO_DEVOPS: paste `ls envs/` output (or "envs/ removed") here.
```

---

## Success Criterion 2 — Zero-change plans on all three moved stacks (HARD GATE)

```sh
for stack in live/dmair/strapi/prod live/dmair/frontend/prod live/dmair/frontend/staging; do
  echo "=== $stack ==="
  (cd "$stack" && terraform init -reconfigure && terraform plan)
done
```

Each `terraform plan` must report `No changes. Your infrastructure matches the configuration.`

```text
TODO_DEVOPS: paste live/dmair/strapi/prod terraform plan No-changes output.
```

```text
TODO_DEVOPS: paste live/dmair/frontend/prod terraform plan No-changes output.
```

```text
TODO_DEVOPS: paste live/dmair/frontend/staging terraform plan No-changes output.
```

If any `terraform init -reconfigure` prompts `Do you want to copy existing state to the new backend?`, answer **NO** and STOP. The state keys are unchanged, so no migration should be needed — a migrate prompt means something's off (stale `.terraform/` cache, or an unintended `backend.tf` edit).

If any plan reports a diff: revert the offending stack's commit (per D-13 each move is independently revertable). The likely cause is a missed relative-path bump.

---

## Success Criterion 3 — State keys unchanged

```sh
aws --profile dmair s3 ls s3://dmair-terraform-prod/ --recursive
```

Expected to include these three keys at the same paths as before Phase 2:
- `bootstrap/terraform.tfstate`
- `strapi/terraform.tfstate`
- `frontend/prod/terraform.tfstate`
- `frontend/staging/terraform.tfstate`

```text
TODO_DEVOPS: paste `aws s3 ls --recursive` output here. Confirm the four state keys above are present at the same paths.
```

---

## Success Criterion 4 — Staging slot directory exists

```sh
test -d live/dmair/staging && cat live/dmair/staging/README.md | head -5
```

Expected: directory exists; README starts with `# live/dmair/staging/`.

```text
TODO_DEVOPS: confirm by running the command above and pasting head -5 of the README.
```

---

## Success Criterion 5 — README reflects new reality (DOCS-01)

Spot-check the new `README.md` for:

- [ ] Title is `dmair-terraform`, not "Runway One Aviation".
- [ ] Directory layout shows `bootstrap/`, `live/dmair/<component>/<env>/`, `modules/`, `policies/`, `.planning/`.
- [ ] Three live stacks (`Strapi CMS`, `Frontend prod`, `Frontend staging`) are each named explicitly.
- [ ] State backend section mentions `use_lockfile = true` and `.tflock` sentinel.
- [ ] `bootstrap/` stack is described.
- [ ] No mention of DynamoDB lock table.

```text
TODO_DEVOPS: tick each box above (or note specific text issues).
```

---

## Phase Exit

- [ ] **REFACTOR-01** — three stacks moved, paths updated
- [ ] **REFACTOR-02** — `live/dmair/staging/` slot reserved with placeholder README
- [ ] **REFACTOR-03** — zero-change plans on all three moved stacks (the hard gate)
- [ ] **DOCS-01** — README rewritten around new layout

Set Outcome above. Commit with: `docs(REFACTOR-03): record live/ layout verification evidence`. Then `/gsd-transition` to advance to Phase 3.
