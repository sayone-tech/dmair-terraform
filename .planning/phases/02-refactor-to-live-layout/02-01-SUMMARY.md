---
phase: 02-refactor-to-live-layout
plan: 01
status: code-only-complete
---

# Plan 02-01 Summary — Move three live stacks to live/dmair/<component>/<env>/

## Status

**code-only-complete.** Three `git mv` operations + per-stack relative-path bumps shipped as three atomic commits (D-13). `terraform init -reconfigure` + zero-change plan per stack deferred to DevOps.

## Moves

| From | To | Path bump | Commit |
|---|---|---|---|
| `envs/strapi/` | `live/dmair/strapi/prod/` | `../../modules/` → `../../../../modules/` (15 refs in main.tf, 11 refs in README.md) | `eb49d2b` |
| `envs/frontend/prod/` | `live/dmair/frontend/prod/` | `../../../modules/` → `../../../../modules/` (6 refs in main.tf) | `ec6dc95` |
| `envs/frontend/staging/` | `live/dmair/frontend/staging/` | `../../../modules/` → `../../../../modules/` (8 refs in main.tf) | `5dbf19b` |

`envs/` directory removed (no remaining content after the three moves).

`terraform fmt -check` clean on every modified `.tf`.

## What's intentionally unchanged

- **State keys** in each `backend.tf` are untouched — `strapi/terraform.tfstate`, `frontend/prod/terraform.tfstate`, `frontend/staging/terraform.tfstate` continue to live at the same S3 key paths. So `terraform init -reconfigure` connects to the existing state on the first try.
- **Module call labels** (e.g. `module "app_s3_bucket"`, `module "cloudfront"`, `module "ec2_instance"`) — every label stays identical. Resource addresses (`module.app_s3_bucket.aws_s3_bucket.website_s3` etc.) do not change. No `moved {}` block is needed.
- **AWS-managed resources** — no resource shape changes at all. The only edits are filesystem paths and (in main.tf) the relative module source strings.

## DevOps verification (phase-wide gate)

```sh
for stack in live/dmair/strapi/prod live/dmair/frontend/prod live/dmair/frontend/staging; do
  (cd "$stack" && terraform init -reconfigure && terraform plan)
done
```

Each `terraform plan` must report `No changes. Your infrastructure matches the configuration.` If any reports a diff, the most likely cause is a missed path update or a `.terraform/` cache stale from before the move — try `rm -rf .terraform/ && terraform init -reconfigure` first; if drift persists, revert the offending stack's commit (each is independently revertable per D-13).

## Hard invariant maintained

Zero AWS-managed resource changes. The rename is purely a filesystem reorg + relative-path bump. Live-infra-is-sacred holds.

## Key files

- moved: `envs/strapi/` → `live/dmair/strapi/prod/` (12 files)
- moved: `envs/frontend/prod/` → `live/dmair/frontend/prod/` (7 files)
- moved: `envs/frontend/staging/` → `live/dmair/frontend/staging/` (7 files)
- removed: `envs/` (empty after moves)
- modified: `live/dmair/strapi/prod/main.tf` (path bump only)
- modified: `live/dmair/strapi/prod/README.md` (path bump in terraform-docs table)
- modified: `live/dmair/frontend/prod/main.tf` (path bump only)
- modified: `live/dmair/frontend/staging/main.tf` (path bump only)
- created: `.planning/phases/02-refactor-to-live-layout/02-01-SUMMARY.md` (this file)
