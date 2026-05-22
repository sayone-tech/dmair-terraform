---
phase: 01-bootstrap-state-backend
plan: 03
status: code-only-complete
---

# Plan 01-03 Summary — Strapi backend rewire to use_lockfile

## Status

**code-only-complete.** Two atomic commits (one per file, independently revertable per D-13) shipped the HCL edits. `terraform init -reconfigure` + `terraform plan` (must report `No changes`) is deferred to DevOps.

## Edits

| File | Change | Line count | Commit |
|---|---|---|---|
| `envs/strapi/backend.tf` | +1 line: `    use_lockfile             = true` after `shared_credentials_files`, `=` at column 30 | 9 → 10 | `d3967bb` `feat(BOOTSTRAP-02): enable use_lockfile on strapi backend` |
| `envs/strapi/providers.tf` | +1 line: `  required_version = "~> 1.15"` as first line inside the `terraform {}` block (above `required_providers`) | 14 → 15 | `588703b` `chore(strapi): pin required_version to ~> 1.15` |

`terraform fmt -check` clean on both files.

## Original task status

| Task | Type | Status |
|---|---|---|
| 1 — Add use_lockfile + required_version | `auto` | **Done.** Two atomic commits per D-13. |
| 2 — Operator runs `init -reconfigure` then `plan` against envs/strapi and verifies `No changes` | `checkpoint:human-verify` | Deferred to DevOps. |

## DevOps verification sequence

1. `cd envs/strapi && terraform init -reconfigure`
   - Expected: `Successfully configured the backend "s3"!`.
   - **Critical:** If Terraform prompts `Do you want to copy existing state to the new backend? (yes/no)` — answer **NO** and STOP. The migrate-state prompt should not appear for a metadata-only `use_lockfile` flip (Pitfall 5 / D-12).
2. `terraform plan`
   - **BOOTSTRAP-02 gate (first of three live stacks).** Expected: `No changes. Your infrastructure matches the configuration.`
   - If any managed-resource diff appears: STOP, revert the offending commit (each is independently revertable), escalate.

## Hard invariant maintained

Zero resource managed by `envs/strapi` is changed. `use_lockfile` is a backend-config setting (affects internal state-locking, not managed resources); `required_version` is a Terraform-CLI floor (affects nothing at AWS). Both are inert until DevOps runs `init -reconfigure`.

## Key files

- modified: `envs/strapi/backend.tf`
- modified: `envs/strapi/providers.tf`
- created: `.planning/phases/01-bootstrap-state-backend/01-03-SUMMARY.md` (this file)
