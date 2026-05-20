---
quick_id: 260520-ntp
phase: quick
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/ROADMAP.md
  - .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md
  - .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md
  - .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md
  - .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md
  - .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md
  - .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md
  - .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md
  - .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md
  - CLAUDE.md
autonomous: true
requirements: []
---

<objective>
Sweep Phase 1 planning artifacts to reflect two operator decisions made 2026-05-20:

1. **No DynamoDB.** Replace all references to the `dmair-terraform-locks` DynamoDB table with S3-native state locking via `use_lockfile = true` in each `backend "s3" {}` block. The `.tflock` sentinel object lives alongside the state object in the same S3 bucket.

2. **Pin Terraform to `~> 1.15`.** `use_lockfile` requires Terraform ≥ 1.10; workstation runs 1.15.3. Every Terraform configuration declaration (bootstrap + three env stacks) sets `required_version = "~> 1.15"`. The repo-level floor in CLAUDE.md goes from `>= 1.0` to `>= 1.10`.

Phase 1 plan structure (6 sub-plans) is unchanged — only contents change. Each file is its own atomic commit.

Rule applied uniformly across edits: where text describes the **chosen approach**, switch to S3-native locking. Where text records **alternatives considered / previously assumed**, keep DynamoDB references intact so the audit trail of the decision is preserved (this applies to RESEARCH.md and CONTEXT.md; the per-plan PLAN.md files describe the chosen approach only and switch fully).

Output: 9 commits, one per file edited.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/01-bootstrap-state-backend/01-CONTEXT.md
@.planning/phases/01-bootstrap-state-backend/01-RESEARCH.md
@.planning/phases/01-bootstrap-state-backend/01-PATTERNS.md
@.planning/phases/01-bootstrap-state-backend/01-02-PLAN.md
@.planning/phases/01-bootstrap-state-backend/01-03-PLAN.md
@.planning/phases/01-bootstrap-state-backend/01-04-PLAN.md
@.planning/phases/01-bootstrap-state-backend/01-05-PLAN.md
@.planning/phases/01-bootstrap-state-backend/01-06-PLAN.md
@CLAUDE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update ROADMAP.md Phase 1 success criteria — drop DynamoDB, switch to S3 .tflock</name>
  <files>.planning/ROADMAP.md</files>
  <action>
    Edit `.planning/ROADMAP.md` Phase 1 section only. Make the following changes; leave every other phase (2/3/4) untouched.

    1. **Phase 1 bullet (line ~10):** change `Self-describing state backend + DynamoDB locking wired into every existing stack` to `Self-describing state backend + S3-native state locking wired into every existing stack`.

    2. **Phase 1 Goal (line ~18):** change `every existing stack writes through the DynamoDB lock table without changing any managed resource` to `every existing stack writes through S3-native state locking (use_lockfile = true) without changing any managed resource`.

    3. **Success Criterion 1 (line ~23):** change `the dmair-terraform-locks DynamoDB table is applied` to `use_lockfile = true is set on the bootstrap backend`. The bootstrap stack no longer creates a DynamoDB table at all — the criterion becomes a pure import-only zero-change verification.

    4. **Success Criterion 2 (line ~24):** change `after dynamodb_table = "dmair-terraform-locks" is added to backend.tf` to `after use_lockfile = true is added to backend.tf`.

    5. **Success Criterion 3 (line ~25):** change `blocks the second one on the DynamoDB lock` to `blocks the second one on the S3 state lock`. Replace `Acquiring state lock. This may take a few moments...` evidence reference with the same string (it is unchanged across lock backends — Terraform prints it for both DynamoDB and use_lockfile).

    6. **Success Criterion 4 (line ~26) — replace entirely:** the old check `aws dynamodb describe-table --table-name dmair-terraform-locks --region us-west-2` is gone. New criterion: `During a held terraform apply against envs/strapi, aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ shows a strapi/terraform.tfstate.tflock sentinel object. After the apply prompt is answered (or Ctrl-C), the .tflock object disappears within seconds (operator verifies: re-run aws s3 ls and observe the object is gone).`

    7. **Plans subsection (line ~28-33):** update plan summaries to drop DynamoDB language. Change `01-02-PLAN.md — Create bootstrap/ stack, import bucket + create lock table` to `01-02-PLAN.md — Create bootstrap/ stack, import bucket, enable use_lockfile on bootstrap backend`. Change `01-06-PLAN.md — Two-terminal concurrent-lock verification + describe-table + VERIFICATION.md` to `01-06-PLAN.md — Two-terminal concurrent-lock verification + .tflock object inspection + VERIFICATION.md`.

    8. **Phase 2 success criterion 5 (line ~45):** change `the DynamoDB lock table` to `S3-native state locking (use_lockfile = true)`. (This is the only Phase 2/3/4 edit — it's a passing reference in the README narrative for the README that Phase 2 will write.)

    Do NOT touch any other line in the file. Do NOT renumber criteria or plans.
  </action>
  <verify>
    grep -c "dynamodb" .planning/ROADMAP.md | grep -q '^0$' && grep -q "use_lockfile = true" .planning/ROADMAP.md && grep -q "tflock" .planning/ROADMAP.md && grep -q "S3-native state locking" .planning/ROADMAP.md
  </verify>
  <done>
    - No occurrences of `dynamodb` (case-insensitive) remain in ROADMAP.md
    - `use_lockfile = true` present at least once
    - `.tflock` sentinel reference present in Success Criterion 4
    - Phase 2/3/4 Plans subsections and other-phase content untouched
    - Atomic commit: `docs(roadmap): drop dynamodb locking from phase 1 success criteria`
  </done>
</task>

<task type="auto">
  <name>Task 2: Update 01-02-PLAN.md — drop aws_dynamodb_table from bootstrap/main.tf, add required_version</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-02-PLAN.md</files>
  <action>
    Comprehensive rewrite of the DynamoDB / lock-table content in `01-02-PLAN.md`. The plan still creates `bootstrap/{backend.tf, providers.tf, main.tf, .terraform.lock.hcl}` and still imports the four S3 sub-resources — only the DynamoDB CREATE goes away.

    1. **Frontmatter `files_modified`:** keep as-is (the four bootstrap files are unchanged at the file-list level).

    2. **Frontmatter `must_haves.truths`:**
       - Remove the truth about `aws_dynamodb_table.this exists in AWS — name=dmair-terraform-locks ...` (the entire bullet — D-06/D-08/D-10 no longer apply to this plan).
       - Update the bootstrap-backend truth to say `use_lockfile = true IS set on bootstrap's own backend (per revised D-01 — S3-native locking is now the chosen approach)`.

    3. **Frontmatter `must_haves.artifacts`:**
       - `bootstrap/backend.tf`: change `provides` from `Self-referential S3 backend at key=bootstrap/terraform.tfstate; no dynamodb_table (D-01)` to `Self-referential S3 backend at key=bootstrap/terraform.tfstate; use_lockfile = true (S3-native locking, D-01 revised)`. Change `contains` to add `use_lockfile = true` alongside `backend "s3"`.
       - `bootstrap/providers.tf`: add to `provides`: `required_version = "~> 1.15"`. Add to `contains`: `required_version`.
       - `bootstrap/main.tf`: change `provides` from `5 resource blocks (4 S3 + 1 DynamoDB) declared inline (D-03); import {} blocks present during first apply, removed after` to `4 resource blocks (4 S3 sub-resources) declared inline (D-03); import {} blocks present during first apply, removed after`. Remove `contains: aws_dynamodb_table`.

    4. **Frontmatter `must_haves.key_links`:**
       - Remove the entire `from: bootstrap/main.tf aws_dynamodb_table.this` → `AWS DynamoDB table dmair-terraform-locks` link entry.

    5. **`<objective>` block:**
       - Change `the first apply (one CREATE for the DynamoDB lock table + four IMPORTs of the existing S3 bucket sub-resources)` to `the first apply (four IMPORTs of the existing S3 bucket sub-resources; no CREATEs)`.
       - Change `the previously-missing dmair-terraform-locks DynamoDB lock table exists in AWS so the three live stacks can be rewired to use it` to `S3-native state locking (use_lockfile = true) is enabled on bootstrap's own backend so the three live stacks can be rewired to use the same mechanism`.
       - Change `Output: 4 new files under bootstrap/ and 1 new DynamoDB table in AWS` to `Output: 4 new files under bootstrap/. No new AWS resources beyond adoption of the existing S3 bucket sub-resources.`

    6. **Task 1 (`Create bootstrap/backend.tf and bootstrap/providers.tf`):**
       - In `<action>`, add to the `bootstrap/backend.tf` instructions: `Inside the backend "s3" {} block, AFTER the shared_credentials_files line and BEFORE the closing brace, add the line: use_lockfile = true (column-30 aligned). This enables S3-native state locking (.tflock sentinel object alongside terraform.tfstate). Replaces D-01's previous "no dynamodb_table on bootstrap" with "use_lockfile = true on bootstrap" — bootstrap is no longer unlocked.`
       - In `<action>`, add to the `bootstrap/providers.tf` instructions: `In the terraform {} block (Block 1), add a required_version = "~> 1.15" argument inside the terraform block (sibling to required_providers). This pins the Terraform CLI floor to 1.15.x; use_lockfile requires ≥ 1.10 and workstation runs 1.15.3.`
       - Update `<verify>` to also check `grep -q 'use_lockfile' bootstrap/backend.tf && grep -q 'required_version' bootstrap/providers.tf && grep -q '~> 1.15' bootstrap/providers.tf`.
       - Update `<done>` correspondingly: add bullet `bootstrap/backend.tf contains use_lockfile = true` and `bootstrap/providers.tf contains required_version = "~> 1.15"`.

    7. **Task 2 (`Create bootstrap/main.tf with 5 resource blocks + 4 import {} blocks`):**
       - Rename the task to `Task 2: Create bootstrap/main.tf with 4 resource blocks + 4 import {} blocks (S3 sub-resources only; no DynamoDB)`.
       - In `<action>`: delete the entire "Resource 5: `resource "aws_dynamodb_table" "this"`" section and all its do-not bullets. Delete the comment-line instruction about `Conceptually "terraform_locks" (D-06)`.
       - Change "the following five resources and four import blocks" to "the following four resources and four import blocks".
       - Drop references to D-06, D-07, D-08, D-09, D-10 from the action prose (those decisions are about the DynamoDB table that no longer exists in this plan).
       - In `<read_first>`, drop D-06/D-07/D-08/D-09/D-10 from the CONTEXT.md reference list (leave D-03).
       - In `<read_first>`, drop the `modules/eip/main.tf (lines 12-14)` reference (it was for DynamoDB protection-intent which no longer applies).
       - In `<verify>`: drop the grep checks for `aws_dynamodb_table`, `name = "dmair-terraform-locks"`, `billing_mode = "PAY_PER_REQUEST"`, `hash_key = "LockID"`, `deletion_protection_enabled = true`, `App_Name = "dmair-terraform"`, `Env_Type = "bootstrap"`, `read_capacity|write_capacity`, `point_in_time_recovery`. Add: `! grep -q 'aws_dynamodb_table' bootstrap/main.tf` (negative check — no DynamoDB resource anywhere in bootstrap).
       - In `<done>`: change `exactly 5 resource blocks` to `exactly 4 resource blocks` and remove the DynamoDB-arguments bullet.

    8. **Task 3 (the BLOCKING checkpoint — first apply sequence):**
       - In `<how-to-verify>` step 2 (terraform plan): change `aws_dynamodb_table.this CREATE (1 resource to add)` to `(no CREATEs — only the 4 S3 IMPORTs)`. Change `Plan: 1 to add, 4 to import, 0 to change, 0 to destroy.` to `Plan: 0 to add, 4 to import, 0 to change, 0 to destroy.`.
       - In step 3 (apply): change `1 CREATE success line (DynamoDB table), 4 IMPORT success lines` to `4 IMPORT success lines (S3 sub-resources). No CREATEs.`.
       - Delete step 5 entirely (the `aws dynamodb describe-table` check) and the paragraph that asks operator to paste TableStatus.
       - In `<acceptance_criteria>`: drop the second bullet about `aws dynamodb describe-table`.
       - In `<resume-signal>`: change `Type "bootstrap-applied" with the No-changes output and the TableStatus value` to `Type "bootstrap-applied" with the No-changes output from step 4`.
       - In Pitfall references in `<read_first>`: drop reference to "§Pitfall 6 — dynamodb_table deprecation warnings" (no longer relevant — we're not using dynamodb_table).

    9. **Task 4 (Remove import {} blocks):** no changes needed — this task is about S3 imports which still exist.

    10. **`<success_criteria>` block:** remove the bullet about `ROADMAP success criterion 4 met: aws dynamodb describe-table ... returns ACTIVE table`. Replace with: `The bootstrap stack is self-describing IaC and its own backend uses S3-native state locking (use_lockfile = true).` Drop the bullet about "DynamoDB lock table dmair-terraform-locks exists in AWS account 071297531943".

    11. **`<output>` block (SUMMARY guidance):** remove `The DynamoDB table ARN (from terraform output or describe-table)` bullet. Change `The five resources now under bootstrap/ Terraform management` to `The four resources now under bootstrap/ Terraform management`.
  </action>
  <verify>
    grep -ic 'dynamodb' .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md | grep -q '^0$' && grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md && grep -q 'required_version' .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-02-PLAN.md
  </verify>
  <done>
    - Zero `dynamodb` references remain in 01-02-PLAN.md (case-insensitive)
    - `use_lockfile` and `required_version = "~> 1.15"` both appear in the plan
    - The "5 resources" framing is now "4 resources" everywhere it appeared
    - Atomic commit: `docs(01): drop dynamodb resource from bootstrap plan`
  </done>
</task>

<task type="auto">
  <name>Task 3: Update 01-03-PLAN.md — use_lockfile on envs/strapi backend.tf + required_version on providers.tf</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-03-PLAN.md</files>
  <action>
    Rewire all DynamoDB-table references in `01-03-PLAN.md` to S3-native locking, and expand the plan to also touch `envs/strapi/providers.tf` for the Terraform pin.

    1. **Frontmatter `files_modified`:** add `envs/strapi/providers.tf` alongside the existing `envs/strapi/backend.tf`.

    2. **Frontmatter `must_haves.truths`:**
       - Replace `envs/strapi/backend.tf declares dynamodb_table = "dmair-terraform-locks" inside the backend "s3" {} block` with `envs/strapi/backend.tf declares use_lockfile = true inside the backend "s3" {} block (S3-native state locking)`.
       - Add a new truth: `envs/strapi/providers.tf declares required_version = "~> 1.15" inside the terraform {} block — use_lockfile requires Terraform ≥ 1.10; workstation runs 1.15.3.`
       - Replace `terraform plan in envs/strapi reports 'No changes...' — first of three live-stack rewires (D-11)` with the same wording — still first of three.

    3. **Frontmatter `must_haves.artifacts`:**
       - Update `envs/strapi/backend.tf`: change `provides` to `Backend block with use_lockfile line added; identical to current shape otherwise`. Change `contains` to `use_lockfile             = true`.
       - Add a new artifact entry for `envs/strapi/providers.tf`: provides `terraform {} block now has required_version = "~> 1.15"; provider block unchanged`, contains `required_version = "~> 1.15"`.

    4. **Frontmatter `must_haves.key_links`:**
       - Replace `envs/strapi/backend.tf dynamodb_table argument` → `AWS DynamoDB table dmair-terraform-locks` link with: from `envs/strapi/backend.tf use_lockfile argument`, to `S3 .tflock sentinel object at s3://dmair-terraform-prod/strapi/terraform.tfstate.tflock`, via `S3-native locking (Terraform 1.10+ feature)`, pattern `use_lockfile = true`.

    5. **`<objective>` block:**
       - Change `Rewire the Strapi CMS stack to use the new DynamoDB lock table via a one-line edit to envs/strapi/backend.tf` to `Rewire the Strapi CMS stack to use S3-native state locking via a one-line edit to envs/strapi/backend.tf, plus a sibling one-line edit to envs/strapi/providers.tf pinning required_version = "~> 1.15"`.
       - Update Output to: `One line added to envs/strapi/backend.tf (use_lockfile = true). One line added to envs/strapi/providers.tf (required_version = "~> 1.15"). Two independent atomic commits (one per file).`
       - Drop the `(D-11 commit order ...)` parenthetical wording IF it still says "rewires to the DynamoDB lock table" — keep the sequencing rule but rephrase to "lock-mechanism rewires".

    6. **Task 1 (`Add dynamodb_table line to envs/strapi/backend.tf`):**
       - Rename to `Task 1: Add use_lockfile and required_version to envs/strapi/{backend.tf, providers.tf}`.
       - Update `<files>` to: `envs/strapi/backend.tf, envs/strapi/providers.tf`.
       - In `<action>`: replace the dynamodb_table insertion instruction with: `Insert exactly ONE line into envs/strapi/backend.tf inside the backend "s3" {} block, immediately after shared_credentials_files and before the closing brace: use_lockfile             = true. 4-space leading indent, use_lockfile followed by 13 spaces to align = at column 30, value true (bare bool, not "true").` Then add a second instruction: `In envs/strapi/providers.tf, inside the existing terraform {} block (which currently contains only required_providers), add a sibling argument required_version = "~> 1.15" as the FIRST line inside the block (above required_providers). This pins the Terraform CLI floor to 1.15.x.`
       - Drop references to D-06 (contract string for DynamoDB table name — no longer applicable). Keep D-11 (sequencing — strapi is first) and D-13 (independently revertable; note the rewire is now TWO commits — backend.tf is one commit, providers.tf is the other).
       - Update `<verify>` to: `grep -q 'use_lockfile             = true' envs/strapi/backend.tf && test $(wc -l < envs/strapi/backend.tf) -eq 10 && grep -q 'required_version = "~> 1.15"' envs/strapi/providers.tf && terraform fmt -check envs/strapi/backend.tf envs/strapi/providers.tf`.
       - Update `<done>`: replace dynamodb_table bullets with use_lockfile + required_version bullets. Note: providers.tf line count increases by 1 (was 14 lines → becomes 15).

    7. **Task 2 (BLOCKING checkpoint):**
       - In `<how-to-verify>` step 2: change `BOOTSTRAP-02 success gate (first of three)` to same wording. Drop the line `A Terraform 1.11+ deprecation warning on dynamodb_table is EXPECTED (Pitfall 6)` (no longer relevant — we're not using dynamodb_table). Replace with: `No deprecation warnings expected — use_lockfile is the current HashiCorp-recommended pattern.`
       - In `<acceptance_criteria>`: change commit-message guidance from `feat(BOOTSTRAP-02): wire strapi backend to dmair-terraform-locks DynamoDB lock table` to TWO commits — `feat(BOOTSTRAP-02): enable use_lockfile on strapi backend` and `chore(strapi): pin required_version to ~> 1.15`.
       - In `<read_first>`: drop reference to RESEARCH Pitfall 6 (dynamodb_table deprecation).

    8. **`<verification>` and `<success_criteria>`:** update the prose — replace `dynamodb_table = "dmair-terraform-locks"` with `use_lockfile = true`; add a note that providers.tf gained required_version.

    9. **`<output>` (SUMMARY guidance):** change `confirmation that envs/strapi/backend.tf is now 10 lines with the dynamodb_table line present` to `confirmation that envs/strapi/backend.tf is now 10 lines with use_lockfile = true present AND envs/strapi/providers.tf has required_version = "~> 1.15"`.
  </action>
  <verify>
    grep -ic 'dynamodb' .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md | grep -q '^0$' && grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md && grep -q 'providers.tf' .planning/phases/01-bootstrap-state-backend/01-03-PLAN.md
  </verify>
  <done>
    - Zero `dynamodb` references in 01-03-PLAN.md
    - `use_lockfile`, `~> 1.15`, and `providers.tf` all appear
    - Atomic commit: `docs(01): switch strapi rewire to use_lockfile + terraform pin`
  </done>
</task>

<task type="auto">
  <name>Task 4: Update 01-04-PLAN.md — same change for envs/frontend/prod</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-04-PLAN.md</files>
  <action>
    Apply the exact same shape of edits as Task 3, but for `envs/frontend/prod/` instead of `envs/strapi/`. Use Task 3's edited 01-03-PLAN.md as the structural template — same field changes, same `<read_first>` adjustments, same `<verify>` shape, same commit-message split into two.

    Specifically:
    1. `files_modified` adds `envs/frontend/prod/providers.tf`.
    2. `must_haves.truths` — swap DynamoDB language for use_lockfile; add required_version truth.
    3. `must_haves.artifacts` — same as Task 3 but pointing at `envs/frontend/prod/` paths; .tflock object lives at `s3://dmair-terraform-prod/frontend/prod/terraform.tfstate.tflock`.
    4. `<objective>` — rephrase from "DynamoDB lock table" to "S3-native state locking" + required_version pin.
    5. Task 1 — rename to add providers.tf, add the required_version insertion instruction, update verify/done.
    6. Task 2 (checkpoint) — drop Pitfall 6 deprecation warning notes, update commit-message guidance to two commits (`feat(BOOTSTRAP-02): enable use_lockfile on frontend-prod backend` and `chore(frontend/prod): pin required_version to ~> 1.15`).
    7. Sequencing note: this is SECOND of three rewires per D-11; that ordering is unchanged.
  </action>
  <verify>
    grep -ic 'dynamodb' .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md | grep -q '^0$' && grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md && grep -q 'envs/frontend/prod/providers.tf' .planning/phases/01-bootstrap-state-backend/01-04-PLAN.md
  </verify>
  <done>
    - Zero `dynamodb` references in 01-04-PLAN.md
    - `use_lockfile`, `~> 1.15`, and `envs/frontend/prod/providers.tf` all appear
    - Atomic commit: `docs(01): switch frontend-prod rewire to use_lockfile + terraform pin`
  </done>
</task>

<task type="auto">
  <name>Task 5: Update 01-05-PLAN.md — same change for envs/frontend/staging + reword BOOTSTRAP-02 phrasing</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-05-PLAN.md</files>
  <action>
    Apply the same shape of edits as Tasks 3 and 4, but for `envs/frontend/staging/`. AND additionally reword references to BOOTSTRAP-02's "DynamoDB lock table" to "S3-native state locking".

    1. `files_modified` adds `envs/frontend/staging/providers.tf`.
    2. `must_haves.truths` — swap DynamoDB language for use_lockfile; add required_version truth; the fourth truth ("BOOTSTRAP-02 fully satisfied: all three live backends now route through the DynamoDB lock table") becomes "BOOTSTRAP-02 fully satisfied: all three live backends now use S3-native state locking (use_lockfile = true) AND have required_version = "~> 1.15" pinned in providers.tf".
    3. `must_haves.artifacts` — same shape as Tasks 3/4 but for `envs/frontend/staging/`. .tflock at `s3://dmair-terraform-prod/frontend/staging/terraform.tfstate.tflock`.
    4. `<objective>` — replace `Rewire the frontend staging stack ... to use the new DynamoDB lock table` with `Rewire the frontend staging stack ... to S3-native state locking`. Update Purpose paragraph similarly: change `every existing live backend (...) is now routed through dmair-terraform-locks and re-initialized` to `every existing live backend (...) now uses use_lockfile = true and is re-initialized; required_version = "~> 1.15" is pinned across the three env stacks`.
    5. Task 1 — rename, add providers.tf, add required_version insertion, update verify/done with the use_lockfile/required_version pair.
    6. Task 2 (checkpoint):
       - Step 2 plan check: drop Pitfall 6 deprecation warning notes.
       - Step 3 (phase-wide sanity check across all four stacks): keep the four-stack zero-change plan check unchanged — that's still the BOOTSTRAP-02 phase-wide gate.
       - Commit-message guidance: split into `feat(BOOTSTRAP-02): enable use_lockfile on frontend-staging backend` + `chore(frontend/staging): pin required_version to ~> 1.15`.
    7. Sequencing: THIRD of three rewires per D-11.
  </action>
  <verify>
    grep -ic 'dynamodb' .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md | grep -q '^0$' && grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md && grep -q 'S3-native state locking' .planning/phases/01-bootstrap-state-backend/01-05-PLAN.md
  </verify>
  <done>
    - Zero `dynamodb` references in 01-05-PLAN.md
    - `use_lockfile`, `~> 1.15`, `S3-native state locking`, and `envs/frontend/staging/providers.tf` all appear
    - BOOTSTRAP-02 phrasing references S3-native locking, not DynamoDB
    - Atomic commit: `docs(01): switch frontend-staging rewire to use_lockfile + terraform pin`
  </done>
</task>

<task type="auto">
  <name>Task 6: Update 01-06-PLAN.md — VERIFICATION.md uses .tflock object check, not describe-table</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-06-PLAN.md</files>
  <action>
    Replace all DynamoDB-evidence requirements in `01-06-PLAN.md` with S3 .tflock-object evidence. The two-terminal concurrent-apply test still runs (same Acquiring state lock string from Terraform) — only the supplementary AWS-side verification changes.

    1. **Frontmatter `must_haves.truths`:**
       - Keep truth 1 (concurrent apply blocks on lock — wording unchanged; D-14, D-15 still apply).
       - Replace truth 2: `aws dynamodb describe-table confirms the dmair-terraform-locks table is ACTIVE with LockID(String) as the hash key — ROADMAP success criterion 4 satisfied` → `aws s3 ls s3://dmair-terraform-prod/strapi/ during a held terraform apply against envs/strapi shows a strapi/terraform.tfstate.tflock sentinel object. After apply prompt is answered/canceled, a second aws s3 ls shows the .tflock object is gone (released within seconds). ROADMAP success criterion 4 satisfied.`
       - Truth 3 (VERIFICATION.md exists ...): update `the describe-table JSON` to `the aws s3 ls output showing the .tflock object during the held apply and its absence after release`.

    2. **Frontmatter `must_haves.artifacts`:**
       - `VERIFICATION.md`: keep the `contains: "Acquiring state lock"` (unchanged — Terraform prints this for use_lockfile too). Add a second `contains: ".tflock"` to ensure VERIFICATION.md captures the S3-side evidence.

    3. **`<objective>` block:**
       - Replace `verify the DynamoDB table shape with describe-table` with `verify the .tflock sentinel object appears and disappears via aws s3 ls during/after the held apply`.
       - Replace `BOOTSTRAP-01 and BOOTSTRAP-02 prove the lock table exists and is wired in` with `BOOTSTRAP-01 and BOOTSTRAP-02 prove use_lockfile is wired into every live backend`.

    4. **Task 1 (two-terminal test):** no structural change needed — Terraform's `Acquiring state lock. This may take a few moments...` string is identical for use_lockfile and DynamoDB locking. BUT: add a note in `<what-built>` that the lock evidence is now in S3 (`.tflock` object) rather than DynamoDB; the operator should be aware they can `aws s3 ls s3://dmair-terraform-prod/strapi/` from a third terminal during the held apply to observe the `.tflock` object directly. Add an OPTIONAL third-terminal observation step in `<how-to-verify>` (between current steps for terminal A and cleanup): `(Optional but recommended for ROADMAP SC 4 evidence) Open a third terminal and run: aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ — expected output includes both terraform.tfstate (the state object) AND terraform.tfstate.tflock (the sentinel lock object created when terminal A acquired the lock). Capture this output for VERIFICATION.md.`

    5. **Task 2 (write VERIFICATION.md):**
       - In `<action>`, replace the `aws dynamodb describe-table` command with: `aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ --human-readable --summarize` (run twice — once during the held apply from Task 1, once after release — to capture the appear/disappear lifecycle). If the optional third-terminal step in Task 1 already captured the held-state output, the operator only needs to run the post-release s3 ls now.
       - Rewrite the "### ROADMAP Success Criterion 4" section:
         OLD: section about DynamoDB describe-table JSON with TableStatus / KeySchema / BillingModeSummary / DeletionProtectionEnabled.
         NEW: section heading remains `### ROADMAP Success Criterion 4: S3-native lock sentinel observed during held apply`. Body: `Paste the aws s3 ls output captured DURING the held terraform apply (Task 1 step 3, optional third terminal) — must show terraform.tfstate.tflock alongside terraform.tfstate. Paste the aws s3 ls output captured AFTER the apply was answered/canceled — must show terraform.tfstate only (the .tflock is gone). Confirm in prose: the .tflock sentinel appeared when terraform acquired the lock and disappeared when it was released.`
       - In `<verify>`: drop the grep checks for `TableStatus`, `LockID`, `PAY_PER_REQUEST`. Add: `grep -q "tflock" .planning/phases/01-bootstrap-state-backend/VERIFICATION.md` and keep `grep -q "Acquiring state lock"`.
       - In `<done>`: replace `describe-table JSON with TableStatus=ACTIVE, LockID hash key, PAY_PER_REQUEST, DeletionProtectionEnabled=true` with `aws s3 ls evidence showing the .tflock sentinel during the held apply and its absence after release`.

    6. **`<verification>` and `<success_criteria>`:** swap "describe-table JSON inspection" for ".tflock object lifecycle observation via aws s3 ls".

    7. **`<output>` (SUMMARY guidance):** replace `describe-table TableStatus/KeySchema confirmation` with `.tflock appear/disappear confirmation via aws s3 ls`.
  </action>
  <verify>
    grep -ic 'dynamodb' .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md | grep -q '^0$' && grep -q 'tflock' .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md && grep -q 'aws s3 ls' .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md && grep -q 'Acquiring state lock' .planning/phases/01-bootstrap-state-backend/01-06-PLAN.md
  </verify>
  <done>
    - Zero `dynamodb` references in 01-06-PLAN.md
    - `.tflock`, `aws s3 ls`, and `Acquiring state lock` all appear
    - VERIFICATION.md content guidance uses S3 .tflock evidence, not describe-table JSON
    - Atomic commit: `docs(01): switch verification evidence to s3 tflock object check`
  </done>
</task>

<task type="auto">
  <name>Task 7: Update 01-CONTEXT.md — chosen approach switches to S3-native locking; preserve audit trail</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-CONTEXT.md</files>
  <action>
    Sweep `01-CONTEXT.md` to reflect the revised chosen approach (S3-native locking + Terraform pin) while keeping the historical decision trail intact.

    Strategy: rewrite the decisions that describe the **chosen mechanism** (D-01, D-06, D-07, D-08, D-09, D-10, D-11, D-12, D-13, D-14, D-15) to reference use_lockfile. Add a brief preamble note that these decisions were revised 2026-05-20. Do NOT delete the original DynamoDB-flavored wording from D-06 through D-10 wholesale — instead move it to a new "Previously Assumed (revised 2026-05-20)" subsection at the end of the file so the audit trail is preserved.

    Specific edits:

    1. **`<domain>` §Phase Boundary (line ~8-9):**
       - Replace `provisions a new dmair-terraform-locks DynamoDB lock table in us-west-2. Then dynamodb_table = "dmair-terraform-locks" is wired into every existing live backend ... and each stack is terraform init -reconfigure'd.` with `enables S3-native state locking (use_lockfile = true) on bootstrap's own backend. Then use_lockfile = true is wired into every existing live backend (envs/strapi, envs/frontend/prod, envs/frontend/staging) AND required_version = "~> 1.15" is pinned in each providers.tf, and each stack is terraform init -reconfigure'd.`
       - Update the "phase is done when" sentence: `a two-terminal concurrent-apply demonstrates the second operator is blocked on the lock` stays unchanged (lock semantics unchanged from the operator's perspective).

    2. **Add a new subsection at the top of `<decisions>`:**
       ```
       > **Revision note (2026-05-20):** Decisions D-01, D-06 through D-15 were originally written around a DynamoDB lock table (dmair-terraform-locks). On 2026-05-20 the operator decided to use Terraform 1.10+'s S3-native state locking (use_lockfile = true) instead, which eliminates the DynamoDB table entirely. The DynamoDB-flavored wording of each affected decision is preserved at the bottom of this file under "Previously Assumed" for audit purposes. The text below reflects the current chosen approach.
       ```

    3. **D-01 (bootstrap's own state):** change `No dynamodb_table on the bootstrap backend itself — it stays unlocked` to `use_lockfile = true on the bootstrap backend itself — bootstrap is locked via the S3-native .tflock sentinel just like every other stack`. Rationale: same as before plus "S3-native locking is built into Terraform 1.10+, so the lock table dance disappears entirely".

    4. **D-02 (provider config):** unchanged.

    5. **D-03, D-04, D-05 (S3 bucket import scope):** unchanged — these are about S3 sub-resource imports, not the lock mechanism.

    6. **D-06 through D-10 (DynamoDB lock table shape):** replace all five with a single revised note:
       ```
       ### DynamoDB lock table shape (REPLACED — see Previously Assumed)
       - **D-06 (revised):** S3-native state locking via `use_lockfile = true` in every `backend "s3" {}` block. No DynamoDB table is provisioned. The `.tflock` sentinel object is written by Terraform alongside the state object in the same S3 bucket during plan/apply.
       - **D-07/D-08/D-09/D-10 (obsolete):** DynamoDB-specific knobs (PITR, deletion_protection, SSE choice, table tagging) no longer apply — there is no table.
       ```

    7. **D-11:** change `Three live backends are rewired one stack at a time, separate commits ... For each: edit backend.tf to add dynamodb_table = "dmair-terraform-locks"` to `... For each: edit backend.tf to add use_lockfile = true AND edit providers.tf to add required_version = "~> 1.15"`. Add note: each stack gains TWO independent commits (backend.tf rewire + providers.tf pin), so per D-13 they remain independently revertable.

    8. **D-12:** unchanged in spirit — `terraform init -reconfigure` is still the recipe; no `-migrate-state` expected for either lock mechanism.

    9. **D-13:** unchanged — independently-revertable atomic commits.

    10. **D-14:** change `aws dynamodb describe-table ... is the artifact for ROADMAP SC 4` framing (if present) to `aws s3 ls of the bucket prefix during the held apply showing the .tflock object is the artifact for ROADMAP SC 4`. The Acquiring state lock string itself is unchanged.

    11. **D-15:** unchanged — strapi remains the chosen test stack.

    12. **Add a new `<previously_assumed>` section at the END of the file (after `<deferred>`):**
       ```
       <previously_assumed>
       ## Previously Assumed (revised 2026-05-20)

       The decisions below were drafted on 2026-05-20 (morning) and superseded later the same day by the switch to S3-native state locking. They are preserved for audit trail of why the original direction was chosen and why it was changed.

       ### Original D-06: aws_dynamodb_table.terraform_locks
       - name = "dmair-terraform-locks", hash key LockID (String), billing_mode = "PAY_PER_REQUEST". PPR is HashiCorp's recommended default for state locking; on this workload (handful of plan/apply runs per day) it costs effectively $0 vs $0.50+/mo for provisioned.

       ### Original D-07: point_in_time_recovery off
       - Locks are ephemeral; stuck locks recovered with terraform force-unlock, not table restore. No backup cost.

       ### Original D-08: deletion_protection_enabled = true
       - Extends existing prevent_destroy convention used on CloudFront/EC2/EIP — the lock table would be load-bearing.

       ### Original D-09: AWS-managed SSE for the lock table
       - DynamoDB tables SSE-encrypted by default since 2018. No customer KMS key — keep blast radius small.

       ### Original D-10: Tagging App_Name="dmair-terraform", Env_Type="bootstrap"
       - Matched project's existing tag-key casing convention.

       ### Why we switched (2026-05-20)
       - Terraform 1.10 made S3-native state locking (`use_lockfile = true`) GA. It writes a `.tflock` sentinel object alongside the state object in the same S3 bucket, so it requires no additional AWS resource. No table to manage, no separate IAM permission set, no separate billing item, no separate "what if the table is deleted" risk. The workstation already runs Terraform 1.15.3, so the version floor is non-binding. The trade-off (loss of separate per-table IAM scoping) is irrelevant because the same operator profile already controls both the bucket and any lock mechanism.
       </previously_assumed>
       ```
  </action>
  <verify>
    grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md && grep -q 'Previously Assumed' .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md && grep -q 'dmair-terraform-locks' .planning/phases/01-bootstrap-state-backend/01-CONTEXT.md
  </verify>
  <done>
    - `use_lockfile` and `~> 1.15` present in chosen-approach decisions
    - `Previously Assumed` section preserves original DynamoDB decisions D-06 through D-10 verbatim
    - The string `dmair-terraform-locks` IS still present (in the Previously Assumed section — audit trail preserved)
    - Chosen-approach text no longer prescribes a DynamoDB table
    - Atomic commit: `docs(01): revise context — switch chosen approach to s3 native locking`
  </done>
</task>

<task type="auto">
  <name>Task 8: Update 01-RESEARCH.md — chosen approach is now use_lockfile; preserve DynamoDB content in alternatives</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-RESEARCH.md</files>
  <action>
    Sweep `01-RESEARCH.md` to reflect the revised chosen approach. The research already contains a "Alternatives Considered" entry that named use_lockfile as the alternative and said "Rejected by user in CONTEXT D-06" — that framing now inverts.

    1. **Add a revision note near the top of the file** (just under the `**Researched:** 2026-05-20` line or just under `## Summary`):
       ```
       > **Revision note (2026-05-20, afternoon):** This research was written assuming a DynamoDB lock table per the morning's CONTEXT.md. The operator switched the chosen approach to S3-native locking (`use_lockfile = true`) the same afternoon. The text below has been edited to reflect that switch in the **Chosen Approach** sections (Summary, Standard Stack, Architecture Patterns, Code Examples). DynamoDB-flavored content is preserved in the **Alternatives Considered** and **Pitfalls** sections as part of the audit trail. Where a pitfall (e.g., Pitfall 1 — PAY_PER_REQUEST under DynamoDB) no longer applies under the chosen approach, the pitfall remains documented but is now annotated `[no longer applies under chosen approach — preserved for audit trail]`.
       ```

    2. **`## Summary` paragraph:** Replace the second sentence about DynamoDB locking deprecation (`DynamoDB-based locking is deprecated in Terraform 1.11+ — dynamodb_table = "..." still works ...`) with: `Terraform 1.10+ supports S3-native state locking via use_lockfile = true; this is the chosen mechanism for this phase, replacing the morning's DynamoDB plan. Workstations must run Terraform ≥ 1.10; this phase pins required_version = "~> 1.15" in every providers.tf (workstation runs 1.15.3).`
       Replace the **Primary recommendation** paragraph's sequencing summary: the bootstrap apply no longer needs to "create the table" — it's now four S3 IMPORTs only, no CREATEs. Edit accordingly.

    3. **`## Architectural Responsibility Map` table:** Change the row `DynamoDB lock table (greenfield)` to `S3 .tflock sentinel object (per-state-key, written by Terraform)`. Primary tier stays `Coordination / Locking`. Rationale: "Written automatically by Terraform 1.10+ when use_lockfile = true is set on backend s3; no additional AWS resource needed."

    4. **`## User Constraints (from CONTEXT.md)` section:**
       - Add a banner: `Revised 2026-05-20 PM — see 01-CONTEXT.md "Previously Assumed" section for the original DynamoDB-flavored decisions.`
       - Update D-01: `use_lockfile = true on bootstrap's own backend` (was: no dynamodb_table).
       - Update D-06 to read: `S3-native state locking via use_lockfile = true; no DynamoDB table provisioned`.
       - Annotate D-07/D-08/D-09/D-10 each with `[Obsolete — see 01-CONTEXT.md Previously Assumed]`.
       - Update D-11: rewires now insert `use_lockfile = true` in backend.tf AND `required_version = "~> 1.15"` in providers.tf, in the same per-stack order.
       - Update D-12: unchanged — init -reconfigure semantics same for use_lockfile.

    5. **`## Standard Stack` §Core table:** Change Terraform CLI row: version `≥ 1.10 (recommended ~> 1.15)`, purpose `Apply + state mgmt + S3-native locking (use_lockfile requires 1.10+)`. Drop the "1.5+ for import {} blocks" note (still true but no longer load-bearing for the lock mechanism).

    6. **`## Standard Stack` §Alternatives Considered table:** Invert the first row. OLD: `Instead of: dynamodb_table = "..."; Could Use: use_lockfile = true (S3 native locking, GA in Terraform 1.11); Tradeoff: HashiCorp's new recommended default ... Rejected by user in CONTEXT D-06 — phase ships with DynamoDB.`. NEW: `Instead of: use_lockfile = true (S3-native, chosen); Could Use: dynamodb_table = "dmair-terraform-locks" (separate DynamoDB table); Tradeoff: DynamoDB locking is the legacy pattern, deprecated by HashiCorp in 1.11+. Adds an additional AWS resource and IAM permission set with no observable benefit on this single-account, single-operator workload. The phase originally chose DynamoDB (CONTEXT D-06 morning), then switched to use_lockfile the same afternoon (CONTEXT D-06 revised). [VERIFIED: developer.hashicorp.com S3 backend docs]`

    7. **`## Standard Stack` §Installation:** drop `dynamodb:CreateTable, dynamodb:DescribeTable, dynamodb:UpdateTable, dynamodb:TagResource` from the required permissions list — no DynamoDB calls happen. Keep `s3:Get*, s3:PutBucketTagging` and ADD `s3:PutObject + s3:DeleteObject on the state-bucket prefix` (Terraform writes/deletes the .tflock object).

    8. **`## Architecture Patterns` §System Architecture Diagram:** in the diagram, change the DynamoDB box to "S3 .tflock sentinel objects (one per state key, ephemeral)". Update Data flow §2: `Live-stack plan: terraform CLI → S3 PutObject (write .tflock sentinel) → S3 GetObject (read state) → diff → S3 DeleteObject (remove .tflock)`.

    9. **`## Architecture Patterns` §Pattern 2:** rename from `aws_dynamodb_table for Terraform state locking (greenfield)` to `[OBSOLETE — see Alternatives Considered] aws_dynamodb_table for Terraform state locking (greenfield)`. Add a banner at the top of the section: `**[OBSOLETE 2026-05-20 PM]** This pattern was the chosen approach as of the morning of 2026-05-20 and was replaced the same afternoon by S3-native locking (use_lockfile = true). Preserved for audit. Plans 01-02 through 01-06 do NOT implement this pattern.` Leave the HCL example and pitfall references intact.

    10. **`## Architecture Patterns` §Pattern 3:** rename to `Pattern 3: Backend block with S3-native state locking (live-stack rewire)`. Update the HCL example to show `use_lockfile = true` instead of `dynamodb_table = "dmair-terraform-locks"`.

    11. **`## Architecture Patterns` Add a new §Pattern 4: required_version pin** with a 4-line HCL example showing `terraform { required_version = "~> 1.15"; required_providers { ... } }`.

    12. **`## Don't Hand-Roll` table:** keep all three rows. Update the first row's `Use Instead` from `aws_dynamodb_table + dynamodb_table = "..." in backend block` to `use_lockfile = true in backend block (Terraform 1.10+ S3-native locking)`. Update Why: `Terraform's built-in S3-native locking via use_lockfile = true is the current canonical pattern (DynamoDB-based locking is the deprecated predecessor and is preserved in this phase's audit trail under Alternatives Considered).`

    13. **`## Validation Architecture` §Phase Requirements → Verification Map:** Update BOOTSTRAP success criterion 4 row. OLD command: `aws dynamodb describe-table --table-name dmair-terraform-locks --region us-west-2 --profile dmair`. NEW command: `(during a held terraform apply against envs/strapi) aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/` → output must include `strapi/terraform.tfstate.tflock`. After apply release, re-run same s3 ls → output must NOT include the .tflock object.

    14. **`## Common Pitfalls` section:** Annotate each pitfall that referenced DynamoDB with `[no longer applies under chosen approach — preserved for audit trail]`. Specifically Pitfalls 1 (PAY_PER_REQUEST), 6 (dynamodb_table deprecation warning). Add a new Pitfall: `### Pitfall 10: .tflock sentinel left behind after a crashed apply (use_lockfile)` — describe that if a terraform apply crashes hard, the `.tflock` object can be left in S3 and block subsequent applies. Recovery: `aws s3 rm s3://dmair-terraform-prod/<state-key>.tflock` (only after confirming no other terraform process holds it).

    15. **`## Code Examples` §Example 3 (bootstrap/backend.tf):** Update — add `use_lockfile = true` to the block. Update the comment from `Intentionally NO dynamodb_table — per CONTEXT D-01, bootstrap is unlocked` to `use_lockfile = true per CONTEXT D-01 (revised 2026-05-20 PM) — bootstrap uses S3-native locking like every other stack`.

    16. **`## Code Examples` §Example 4 (bootstrap/providers.tf):** Add a `required_version = "~> 1.15"` line at the top of the `terraform {}` block (above `required_providers`).

    17. **`## Code Examples` §Example 5 (first-apply sequence):** Drop the bullet `aws_dynamodb_table.this CREATE (new)` from the expected plan output. Change `Total: 1 to add, 4 to import, 0 to change, 0 to destroy.` to `Total: 0 to add, 4 to import, 0 to change, 0 to destroy.`. Change `5 success lines` to `4 success lines (S3 IMPORTs only)`.

    18. **`## Code Examples` §Example 6 (per-stack rewire):** Change `Edit envs/strapi/backend.tf — add: dynamodb_table = "dmair-terraform-locks"` to `Edit envs/strapi/backend.tf — add: use_lockfile = true. Edit envs/strapi/providers.tf — add: required_version = "~> 1.15"`. Drop the `A deprecation warning on dynamodb_table (Terraform 1.11+) is EXPECTED — Pitfall 6` line.

    19. **`## State of the Art` table:** Update the third row's current-approach: was `dynamodb_table = "..." in backend "s3" block` — change "current" cell to: `use_lockfile = true (S3 native locking, GA Terraform 1.11). The phase initially chose DynamoDB (CONTEXT D-06 morning of 2026-05-20) then switched to use_lockfile the same afternoon — see CONTEXT.md Previously Assumed.`

    20. **`## Sources` section:** No deletions — sources are still valid. Optionally add a note: `S3 backend use_lockfile documentation: developer.hashicorp.com/terraform/language/backend/s3#use_lockfile — verified.`
  </action>
  <verify>
    grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md && grep -q 'Revision note' .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md && grep -q 'tflock' .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md && grep -q 'dmair-terraform-locks' .planning/phases/01-bootstrap-state-backend/01-RESEARCH.md
  </verify>
  <done>
    - `use_lockfile`, `Revision note`, `~> 1.15`, `.tflock` all present
    - DynamoDB references remain ONLY in alternatives-considered / previously-assumed contexts (the literal string `dmair-terraform-locks` is still findable in the file because the alternatives row + obsolete-Pattern-2 audit trail preserve it)
    - Chosen-approach sections (Summary, Standard Stack Core, Pattern 3, Code Examples 3/4/5/6, Validation Architecture) all describe use_lockfile, not DynamoDB
    - Atomic commit: `docs(01): revise research — chosen approach switches to use_lockfile`
  </done>
</task>

<task type="auto">
  <name>Task 9: Update 01-PATTERNS.md — drop DynamoDB-table sub-pattern; add use_lockfile + required_version pattern</name>
  <files>.planning/phases/01-bootstrap-state-backend/01-PATTERNS.md</files>
  <action>
    Sweep `01-PATTERNS.md` to reflect that bootstrap/main.tf no longer maps an `aws_dynamodb_table` resource and that backend.tf rewires no longer add `dynamodb_table = "..."`.

    1. **Add a revision banner near the top** (under `**Mapped:** 2026-05-20`):
       ```
       > **Revision note (2026-05-20 PM):** Originally mapped patterns for an `aws_dynamodb_table` resource in `bootstrap/main.tf` and `dynamodb_table = "dmair-terraform-locks"` line additions in the three `envs/*/backend.tf` files. Operator switched to S3-native state locking (`use_lockfile = true`) the same afternoon. Patterns below have been updated:
       > - DynamoDB-table mapping (Sub-pattern 2) is removed.
       > - Backend.tf insertions now add `use_lockfile = true` instead of `dynamodb_table`.
       > - A new pattern for `required_version = "~> 1.15"` in each `providers.tf` is added.
       ```

    2. **`## File Classification` table:**
       - `bootstrap/main.tf` row: change Data Flow from `greenfield CREATE + 4× declarative IMPORT` to `4× declarative IMPORT (S3 sub-resources only)`. Drop the `modules/eip/main.tf (lifecycle/prevent-destroy intent)` analog — no longer relevant. Closest Analog becomes just `modules/s3/main.tf (S3 sub-resource shapes)`.
       - Add a row for each env's `providers.tf` (NEW MODIFICATION): `envs/strapi/providers.tf`, `envs/frontend/prod/providers.tf`, `envs/frontend/staging/providers.tf` — Role `terraform-config (Terraform CLI pin)`, Data Flow `none`, Closest Analog `self (1-line edit adding required_version)`, Match Quality `exact`.

    3. **`## Pattern Assignments` §`bootstrap/backend.tf`:**
       - Remove the line `Do NOT add dynamodb_table — bootstrap is the only unlocked stack (CONTEXT D-01).`
       - Add: `Insert use_lockfile = true inside the backend "s3" {} block, after shared_credentials_files, before the closing brace. Column-30 aligned. Per CONTEXT D-01 (revised 2026-05-20 PM) — bootstrap is now locked via S3-native .tflock just like the three env stacks.`
       - Update the "Verbatim shape from analog" to show the rewired form (with `use_lockfile = true` line included) so the planner sees the post-edit shape inline.

    4. **`## Pattern Assignments` §`bootstrap/providers.tf`:**
       - Add to "Pattern to copy": `Add required_version = "~> 1.15" as the FIRST argument inside the terraform {} block (sibling to required_providers, on its own line above the required_providers nested block). Per CONTEXT D-02 (revised 2026-05-20 PM) — use_lockfile requires Terraform ≥ 1.10; workstation runs 1.15.3.`
       - Update both Variant A and Variant B examples to include `required_version = "~> 1.15"`.
       - Remove the line `No required_version constraint — none of the existing envs/*/providers.tf files set one (RESEARCH §Open Questions #3 flags this as an open question; matching existing pattern means omitting it).` — that statement is now inverted: bootstrap and the three env stacks all gain `required_version = "~> 1.15"`.

    5. **`## Pattern Assignments` §`bootstrap/main.tf` §Sub-pattern 2:** Delete the entire sub-section "Sub-pattern 2: DynamoDB table (greenfield — no existing DynamoDB resource in repo)". Replace with:
       ```
       #### Sub-pattern 2: REMOVED (DynamoDB table no longer in scope as of 2026-05-20 PM)

       Bootstrap no longer provisions any DynamoDB resource. The S3-native locking mechanism (`use_lockfile = true` in the backend block) requires no resource graph involvement at all. The original Sub-pattern 2 — which mapped `aws_dynamodb_table.this` against a non-existent repo analog and a RESEARCH.md template — is obsolete. Patterns for the four S3 sub-resources (Sub-pattern 1) and file composition (Sub-pattern 3) remain in force.
       ```

    6. **`## Pattern Assignments` §`bootstrap/main.tf` §Sub-pattern 3:** Update the recommendation: change `Single main.tf holds all five resources (aws_s3_bucket.this, aws_s3_bucket_versioning.this, ..., aws_dynamodb_table.this) plus their four import {} blocks` to `Single main.tf holds four resources (aws_s3_bucket.this, aws_s3_bucket_versioning.this, aws_s3_bucket_server_side_encryption_configuration.this, aws_s3_bucket_public_access_block.this) plus their four import {} blocks. No DynamoDB resource.`

    7. **`## Pattern Assignments` §`envs/strapi/backend.tf` (MODIFIED — 1-line edit):**
       - Change the section header note from "1-line edit" to "1-line edit + sibling 1-line edit in providers.tf".
       - In Edit instructions: replace `dynamodb_table = "dmair-terraform-locks"` with `use_lockfile = true`. Update the Final shape HCL block accordingly.
       - Update the post-edit operator sequence: terraform init -reconfigure → terraform plan → expect No changes → commit. SAME flow, no DynamoDB.
       - Add a parallel "ALSO: edit envs/strapi/providers.tf" subsection — insert `required_version = "~> 1.15"` as the first argument in the terraform {} block. Same commit-message-per-file rule (D-13 — independently revertable). The plan now produces TWO commits for envs/strapi: one for backend.tf (use_lockfile), one for providers.tf (required_version pin).

    8. **`## Pattern Assignments` §`envs/frontend/prod/backend.tf` and §`envs/frontend/staging/backend.tf`:** Same change as the strapi section — replace dynamodb_table insertion with use_lockfile insertion; add the providers.tf required_version companion edit.

    9. **`## Shared Patterns`:**
       - §Tag-Key Casing (App_Name, Env_Type): the only consumer of this pattern was `aws_dynamodb_table.this.tags`. Now there's no DynamoDB table. Annotate the section: `[OBSOLETE for Phase 1 as of 2026-05-20 PM — DynamoDB table no longer in scope; bootstrap has no tagged resources of its own. This pattern still applies repo-wide; just not exercised by Phase 1.]`
       - §Protection-on-load-bearing-resources Intent: previously applied to `aws_dynamodb_table.this`. Annotate: `[OBSOLETE for Phase 1 as of 2026-05-20 PM — DynamoDB table no longer in scope. The .tflock S3 object is ephemeral and self-managing; no equivalent "protect from destruction" knob is needed or available.]`
       - Add a NEW shared pattern: §Terraform required_version pin. Source: NEW for Phase 1 (none of the existing envs/*/providers.tf set one today, per RESEARCH §Open Questions #3, but Phase 1 introduces it). Apply to: `bootstrap/providers.tf`, `envs/strapi/providers.tf`, `envs/frontend/prod/providers.tf`, `envs/frontend/staging/providers.tf`. Shape: `terraform { required_version = "~> 1.15"; required_providers { ... } }`. Rationale: `use_lockfile = true requires Terraform ≥ 1.10; workstation runs 1.15.3; ~> 1.15 pins minor-version flexibility within 1.15.x.`

    10. **`## Patterns With No Direct Analog in Repo` table:**
        - Drop the row `aws_dynamodb_table resource`.
        - Drop the row `dynamodb_table argument in backend "s3" block`.
        - Add row: `use_lockfile = true in backend "s3" block` — Why No Analog: `No existing backend.tf in repo declares use_lockfile (it's a Terraform 1.10+ feature; repo has no 1.10+ pins yet)`. Authoritative Source: `RESEARCH §Pattern 3 (revised) + developer.hashicorp.com/terraform/language/backend/s3#use_lockfile`.
        - Add row: `required_version constraint in terraform {} block` — Why No Analog: `None of the existing envs/*/providers.tf set required_version (CONCERNS.md flags this); Phase 1 introduces it`. Authoritative Source: `RESEARCH §Pattern 4 (NEW) + developer.hashicorp.com/terraform/language/settings#specifying-a-required-terraform-version`.
  </action>
  <verify>
    grep -q 'use_lockfile' .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md && grep -q 'required_version' .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md && grep -q '~> 1.15' .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md && grep -q 'Revision note' .planning/phases/01-bootstrap-state-backend/01-PATTERNS.md
  </verify>
  <done>
    - `use_lockfile`, `required_version`, `~> 1.15`, `Revision note` all present
    - Sub-pattern 2 (DynamoDB table) is explicitly marked REMOVED
    - Per-env providers.tf rows added to File Classification
    - New shared pattern (required_version pin) documented
    - Atomic commit: `docs(01): revise patterns map — drop dynamodb table, add use_lockfile + required_version`
  </done>
</task>

<task type="auto">
  <name>Task 10: Update CLAUDE.md — bump Terraform floor to >= 1.10, switch DynamoDB lock prose to S3-native locking</name>
  <files>CLAUDE.md</files>
  <action>
    Edit `/Users/mithin/Projects/DMAir/dmair-terraform/CLAUDE.md` (the project-local file, NOT the global `/Users/mithin/CLAUDE.md`).

    1. **Locate the "Platform Requirements" line that reads `Terraform CLI >= 1.0`** (under the ## Technology Stack section). Change it to `Terraform CLI >= 1.10`. Add a sibling bullet immediately below: `Each Terraform workspace pins required_version = "~> 1.15" in its providers.tf as of Phase 1 (workstation runs 1.15.3; >= 1.10 is the absolute floor because S3-native state locking via use_lockfile = true requires it).`

    2. **Locate any other "Terraform CLI >= 1.0" or "Terraform >= 1.0" prose** elsewhere in CLAUDE.md and update to `>= 1.10` for consistency. Likely candidates: the `## Runtime` subsection (`Terraform CLI >= 1.0 (referenced in setup docs; lockfile is present per-workspace)`) — change to `Terraform CLI >= 1.10 (Phase 1 onward — required for S3-native state locking; per-workspace pin is "~> 1.15")`. Also the `## Constraints` block at the top under `## Project` — update `Terraform CLI ≥ 1.0` to `Terraform CLI ≥ 1.10`.

    3. **Locate the line under `## Platform Requirements` that reads:** `Terraform state stored remotely in S3 bucket dmair-terraform-prod (region us-west-2)` AND the next line `State keys: strapi/terraform.tfstate, frontend/staging/terraform.tfstate, frontend/prod/terraform.tfstate` AND the line `No state locking (DynamoDB) configured — S3 backend only`. Replace the third of those three lines with: `State locking via S3-native use_lockfile = true (Terraform 1.10+ feature) — a .tflock sentinel object is written alongside each terraform.tfstate during plan/apply. No DynamoDB table.`

    4. **`## State Backend Pattern` subsection** (if present under `## Conventions` or `## Architecture`): if the prose currently says anything like `No DynamoDB lock table configured` or `S3-only backend, no locking`, update to: `S3 backend with S3-native state locking (use_lockfile = true, Terraform 1.10+). The .tflock sentinel object lives alongside the state object in the same bucket prefix.`

    5. **`## Architectural Constraints` subsection** (under `## Architecture`): if the prose currently mentions "No state locking via DynamoDB lock table is absent from all backend.tf configurations" or similar, change to: `S3-native state locking (use_lockfile = true) is configured in every backend.tf as of Phase 1. The .tflock sentinel object is written by Terraform to the same S3 prefix as terraform.tfstate during plan/apply. No DynamoDB lock table — the previously-considered approach was superseded the same afternoon (2026-05-20) it was scoped.`

    6. **`## Anti-Patterns` subsection `### Missing DynamoDB State Locking`** (if present): rename to `### Missing State Locking [RESOLVED in Phase 1]` and add a body sentence: `Phase 1 (Bootstrap State Backend) enables S3-native state locking (use_lockfile = true) on every backend, including the new bootstrap/ stack. The legacy DynamoDB-table approach was scoped on 2026-05-20 morning and replaced by use_lockfile the same afternoon.`

    7. Do NOT edit `/Users/mithin/CLAUDE.md` (the global user CLAUDE.md) — that's a different file outside the repo. Only edit the repo-local `CLAUDE.md`.
  </action>
  <verify>
    grep -q '>= 1.10' CLAUDE.md && grep -q 'use_lockfile' CLAUDE.md && grep -q '~> 1.15' CLAUDE.md && ! grep -q 'No state locking (DynamoDB) configured' CLAUDE.md
  </verify>
  <done>
    - `>= 1.10` (or `≥ 1.10`) replaces `>= 1.0` / `≥ 1.0` in the Terraform floor references
    - `use_lockfile = true` appears at least once
    - `~> 1.15` appears at least once (the per-workspace pin)
    - The old `No state locking (DynamoDB) configured — S3 backend only` line is gone
    - Atomic commit: `chore(claude): bump terraform floor to 1.10 and switch to s3 native locking prose`
  </done>
</task>

</tasks>

<verification>
After all 9 tasks complete:
- 9 atomic commits land (one per file edited)
- `grep -ric 'dynamodb' .planning/phases/01-bootstrap-state-backend/ .planning/ROADMAP.md CLAUDE.md` returns:
  - **Zero** matches in: ROADMAP.md, 01-02-PLAN.md, 01-03-PLAN.md, 01-04-PLAN.md, 01-05-PLAN.md, 01-06-PLAN.md, CLAUDE.md
  - **Non-zero (preserved audit trail)** matches in: 01-CONTEXT.md (Previously Assumed section), 01-RESEARCH.md (Alternatives Considered + obsolete Pattern 2 + annotated pitfalls), 01-PATTERNS.md (only in the revision banner that says it's removed)
- `grep -r 'use_lockfile' .planning/ CLAUDE.md` returns hits in all 10 edited files.
- `grep -r '~> 1.15' .planning/ CLAUDE.md` returns hits in 01-02, 01-03, 01-04, 01-05, 01-CONTEXT, 01-RESEARCH, 01-PATTERNS, CLAUDE.md.
</verification>

<success_criteria>
- Phase 1 plans (01-02 through 01-06) describe the chosen approach as S3-native state locking with required_version = "~> 1.15" pinned in every providers.tf.
- ROADMAP.md Phase 1 success criteria reference the .tflock sentinel object check, not aws dynamodb describe-table.
- 01-CONTEXT.md and 01-RESEARCH.md preserve the original DynamoDB-flavored decisions in clearly-labeled "Previously Assumed" / "Alternatives Considered" sections so the audit trail of the switch is intact.
- 01-PATTERNS.md explicitly marks Sub-pattern 2 (DynamoDB table) as REMOVED and adds new patterns for use_lockfile and required_version.
- CLAUDE.md's Terraform CLI floor is now `>= 1.10` and its state-backend prose reflects S3-native locking.
- Each file is committed as a single atomic commit per operator's explicit `One atomic commit per edited file is fine` instruction.
</success_criteria>

<output>
After completion, no SUMMARY file is required (quick mode). All evidence lives in the 9 atomic commits on this branch.
</output>
