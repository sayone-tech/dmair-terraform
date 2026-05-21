---
phase: 02-refactor-to-live-layout
plan: 03
status: complete
---

# Plan 02-03 Summary — Full README.md rewrite

## Status

**complete.** Pure documentation; no AWS interaction.

## What changed

Full rewrite of root `README.md`:

- Title: `Infrastructure as Code - Runway One Aviation` → `dmair-terraform`. Legacy "Runway One Aviation" framing dropped entirely (per DOCS-01).
- Directory layout reflects the new `bootstrap/` + `live/dmair/<env>/<component>/` + `modules/` + `policies/` tree.
- New **State backend** section describes S3-native locking via `use_lockfile = true`, the `.tflock` sentinel object lifecycle, and the per-workspace state-key table. Explicitly notes there is **no DynamoDB lock table**.
- Three live stacks named individually: Strapi CMS (`live/dmair/prod/strapi/`), Frontend prod (`live/dmair/prod/frontend/`), Frontend staging (`live/dmair/staging/frontend/`) — each with purpose, domain, and resource list.
- New **Operator quick-start** section covers CLI floor (`>= 1.10`), `dmair` profile minimum IAM perms (`s3:Get/Put/Delete/ListBucket` on `dmair-terraform-prod`), plan/apply workflow, and how to observe state locking via `aws s3 ls`.
- New **Conventions** section lists HCL formatting, module sourcing, provider/CLI pin rules, resource label convention (`.this`), lifecycle locks (CloudFront/EC2/EIP `prevent_destroy = true`), and the secrets-never-committed rule.
- **Roadmap** pointer + **Cross-repo** contracts (DNS, OIDC role) noted.

Commit: `e24dfe4` `docs(DOCS-01): rewrite README around live/ layout and use_lockfile`.

File: 336 → 163 lines (more focused).

Satisfies **DOCS-01**.
