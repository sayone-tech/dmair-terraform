---
quick_id: 260520-ntp
description: Drop DynamoDB locking from Phase 1, use S3-native use_lockfile and bump Terraform pin to ~> 1.15
date: 2026-05-20
status: complete
commit_count: 10
---

# Quick Task 260520-ntp — Summary

## What changed

Operator decisions on 2026-05-20:

1. **No DynamoDB.** Phase 1 switches from a `dmair-terraform-locks` DynamoDB table to Terraform 1.10+'s S3-native `use_lockfile = true` (the `.tflock` sentinel object lives alongside each state object in `s3://dmair-terraform-prod/`).
2. **Terraform pin → `~> 1.15`.** Was `>= 1.0`. `use_lockfile` requires ≥ 1.10; the floor was bumped repo-wide and the chosen pin tracks the current stable line (workstation runs 1.15.3).

## Files edited (10 atomic commits)

| # | Hash | File | Commit message |
|---|------|------|----------------|
| 1 | d2918ea | .planning/ROADMAP.md | docs(roadmap): drop dynamodb locking from phase 1 success criteria |
| 2 | 1c015a4 | .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md | docs(01): drop dynamodb resource from bootstrap plan |
| 3 | c991966 | .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md | docs(01): switch strapi rewire to use_lockfile + terraform pin |
| 4 | 1fc6a6c | .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md | docs(01): switch frontend-prod rewire to use_lockfile + terraform pin |
| 5 | c48aab8 | .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md | docs(01): switch frontend-staging rewire to use_lockfile + terraform pin |
| 6 | 076b370 | .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md | docs(01): switch verification evidence to s3 tflock object check |
| 7 | c5fc9cf | .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md | docs(01): revise context — switch chosen approach to s3 native locking |
| 8 | 8eee39c | .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md | docs(01): revise research — chosen approach switches to use_lockfile |
| 9 | 2cd5fce | .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md | docs(01): revise patterns map — drop dynamodb table, add use_lockfile + required_version |
| 10 | 015809f | CLAUDE.md | chore(claude): bump terraform floor to 1.10 and switch to s3 native locking prose |

Merge commit: `6857c09 chore: merge quick task worktree (worktree-agent-a031fbaabdc5490fe)`.

## Audit trail preserved

DynamoDB references intentionally retained for historical context in:

- `01-CONTEXT.md` — "Previously Assumed" section, documenting the original Phase 1 design before the 2026-05-20 decision.
- `01-RESEARCH.md` — alternatives-considered, obsolete Pattern 2, and annotated pitfalls so the research record explains *why* DynamoDB was rejected.

All forward-looking acceptance criteria, verify commands, and chosen-approach prose now reference `use_lockfile = true` and `.tflock` evidence exclusively.

## Verification (grep gates)

- `grep -ri 'dynamodb' .planning/ROADMAP.md .planning/phases/01-bootstrap-state-backend/01-0*-PLAN.md` → 0 matches
- `grep -r 'use_lockfile' .planning/phases/01-bootstrap-state-backend/` → present in 01-02, 01-03, 01-04, 01-05, 01-06, 01-CONTEXT, 01-RESEARCH, 01-PATTERNS
- `grep -r '~> 1.15' .planning/phases/01-bootstrap-state-backend/ CLAUDE.md` → present everywhere a Terraform version is declared

## What did not change

- The 6-plan structure of Phase 1 (01-01 through 01-06) is intact — only contents were rewritten.
- Phase 2/3/4 plans were not touched (they are not yet generated).
- No source/code/Terraform files were modified — this was a planning-artifact-only sweep.
- `hashicorp/aws` provider pin remains `5.91.0` (operator did not ask to bump it).

## Next step

Execute Phase 1 starting at plan `01-01-PLAN.md` (`/gsd-execute-phase 1`). The plan files are now coherent with the new locking mechanism and the live infra is sacred invariant is unchanged.
