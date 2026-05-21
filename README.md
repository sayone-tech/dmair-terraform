# dmair-terraform

AWS infrastructure-as-code for the `flydmair.com` product surface — a Strapi CMS, a marketing/SPA frontend (`www.flydmair.com`, `flydmair.com`), a staging frontend (`staging.flydmair.com`), and (Phase 3 onward) a staging backend (`api-staging.flydmair.com`).

**Region:** `us-west-2` (all stacks)
**AWS account:** single shared `dmair` account, profile `dmair`
**Terraform:** `>= 1.10` (S3-native state locking via `use_lockfile = true` requires it); workspaces pin `required_version = "~> 1.15"`
**AWS provider:** `hashicorp/aws` pinned at `5.91.0` across every workspace
**Modules:** local `../../../../modules/...` paths only — no Terraform Registry modules

## Directory layout

```
dmair-terraform/
├── bootstrap/                          # State backend (S3 bucket + locking) as IaC.
│                                       # Adopts pre-existing dmair-terraform-prod.
│                                       # State key: bootstrap/terraform.tfstate
│
├── platform/                           # Account-wide foundational resources.
│   └── oidc/                           # GitHub Actions OIDC IDP + dmair-terraform CI
│                                       # roles (plan-readonly, staging-apply, prod-apply).
│                                       # State key: platform/oidc/terraform.tfstate
│
├── live/dmair/                         # Project-keyed live workloads.
│   ├── prod/
│   │   ├── strapi/                     # Strapi CMS (cms.flydmair.com).
│   │   │                               # State key: strapi/terraform.tfstate
│   │   └── frontend/                   # Marketing/SPA prod
│   │                                   #   (www.flydmair.com, flydmair.com).
│   │                                   # State key: frontend/prod/terraform.tfstate
│   └── staging/
│       ├── frontend/                   # Staging frontend (staging.flydmair.com).
│       │                               # State key: frontend/staging/terraform.tfstate
│       └── backend/                    # dmair-backend staging slot
│                                       #   (api-staging.flydmair.com).
│                                       # Hosts dmair-backend-staging-deploy OIDC role.
│                                       # State key: staging/backend/terraform.tfstate
│
├── modules/                            # Reusable local Terraform modules.
│   ├── cloudfront/                     #   CloudFront distribution + OAC.
│   ├── cloudfront-function/            #   Viewer-request JS functions.
│   ├── ec2/                            #   EC2 instance + AMI lookup.
│   ├── ecr/                            #   ECR repository.
│   ├── eip/                            #   Elastic IP.
│   ├── iam-policy/                     #   Renders policies/*.tpl into IAM policies.
│   ├── iam-role/                       #   IAM role + managed-policy attachments.
│   ├── iam-user/                       #   IAM user + access keys.
│   ├── s3/                             #   S3 bucket (versioning/CORS/website opt-ins).
│   ├── secrets_manager/                #   AWS Secrets Manager secret.
│   └── sg/                             #   Security group with default ingress.
│
├── policies/                           # IAM policy JSON templates (templatefile).
│   ├── s3_rw.tpl                       #   App data buckets
│   ├── ecr_push.tpl / ecr_pull.tpl     #   Container registry access
│   ├── cloudfront_invalidate.tpl
│   ├── secrets_manager_read.tpl
│   ├── sg_manage.tpl
│   ├── ses_send_mail.tpl
│   ├── ec2_app_runtime.tpl             #   EC2 instance role (Phase 3)
│   ├── github_app_deploy.tpl           #   dmair-backend-staging-deploy role
│   ├── tf_plan_readonly.tpl            #   Terraform CI plan role
│   ├── tf_staging_apply.tpl            #   Terraform CI staging-apply role
│   └── tf_prod_apply.tpl               #   Terraform CI prod-apply role
│
└── .planning/                          # GSD workflow artifacts (ROADMAP, phases, state).
```

## State backend

Every workspace stores Terraform state in a single S3 bucket (`dmair-terraform-prod`, `us-west-2`) differentiated by state key:

| Workspace | State key |
|---|---|
| `bootstrap/`                     | `bootstrap/terraform.tfstate` |
| `platform/oidc/`                 | `platform/oidc/terraform.tfstate` |
| `live/dmair/prod/strapi/`        | `strapi/terraform.tfstate` |
| `live/dmair/prod/frontend/`      | `frontend/prod/terraform.tfstate` |
| `live/dmair/staging/frontend/`   | `frontend/staging/terraform.tfstate` |
| `live/dmair/staging/backend/`    | `staging/backend/terraform.tfstate` |

**State locking** uses Terraform 1.10+'s S3-native `use_lockfile = true` — every plan/apply writes a `.tflock` sentinel object alongside the state object in the same bucket prefix. **There is no DynamoDB lock table.** Locking evidence (the `.tflock` object) is observable via `aws s3 ls s3://dmair-terraform-prod/<key-prefix>/` during a held apply.

The `bootstrap/` stack adopts the state bucket itself into IaC via `terraform import`. Its four sub-resources (`aws_s3_bucket`, `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`, `aws_s3_bucket_public_access_block`) are managed; bucket policy, lifecycle rules, and access logging are intentionally out-of-scope.

## Live stacks

### Strapi CMS — `live/dmair/prod/strapi/`

**Purpose:** Headless CMS on EC2 backing `cms.flydmair.com`.
**Domain:** `cms.flydmair.com` (EC2 + Caddy + Let's Encrypt). Media + assets served from `strapi-cdn.flydmair.com` via CloudFront.
**Resources:**
- EC2 (`t3.small`, Ubuntu 22.04) with Elastic IP, `prevent_destroy = true`.
- S3 bucket for media + CloudFront distribution.
- ECR repository for Strapi container images.
- Security Group with default-plus-CI ingress (GitHub Actions + Jenkins IP allowlists).
- AWS Secrets Manager for application secrets.
- IAM: instance role + GitHub Actions deploy user + Strapi app user.

Stack-local docs: [`live/dmair/prod/strapi/README.md`](live/dmair/prod/strapi/README.md), [`ENV_VARS_GUIDE.md`](live/dmair/prod/strapi/ENV_VARS_GUIDE.md), [`GITHUB_ACTIONS_SETUP.md`](live/dmair/prod/strapi/GITHUB_ACTIONS_SETUP.md).

### Frontend prod — `live/dmair/prod/frontend/`

**Purpose:** Marketing site + SPA serving `www.flydmair.com` and `flydmair.com`.
**Resources:**
- S3 static-site bucket + CloudFront distribution with OAC (Origin Access Control).
- CloudFront viewer-request function `url_rewrite.js` for clean URLs.
- ACM certificate (must live in `us-east-1` — CloudFront requirement).
- Secrets Manager for build-time env vars.
- IAM: GitHub Actions deploy user.

### Frontend staging — `live/dmair/staging/frontend/`

**Purpose:** Pre-production preview at `staging.flydmair.com`.
**Differs from prod:** adds CloudFront viewer-request `basic_auth.js` (HTTP Basic) to gate access; otherwise identical shape (S3 + CloudFront + OAC + Secrets Manager + IAM deploy user).

## Operator quick-start

### Prerequisites

```sh
brew install hashicorp/tap/terraform     # CLI >= 1.10 (workstation runs 1.15.3)
aws configure list-profiles               # 'dmair' must be present
```

The `dmair` profile must resolve to an IAM identity with:
- Read on every AWS resource it touches.
- `s3:GetObject` / `s3:PutObject` / `s3:DeleteObject` / `s3:ListBucket` on `arn:aws:s3:::dmair-terraform-prod` (for state + `.tflock` writes during plan/apply).
- `sts:GetCallerIdentity`.
- Per-stack permissions for the resources actually being managed by that stack.

### Plan + apply a stack

```sh
cd live/dmair/prod/strapi          # or any other workspace
terraform init                      # first time only; -reconfigure if backend.tf changed
terraform plan                      # MUST report "No changes" against unmodified live infra
terraform apply                     # type 'yes' if a change is intentional
```

**Live-infra-is-sacred:** for any refactor commit, every existing live stack's `terraform plan` must report `No changes. Your infrastructure matches the configuration.` That is the hard gate — diff that doesn't match expectation means stop and revert.

### Observe state locking

During a held `terraform apply`:
```sh
aws --profile dmair s3 ls s3://dmair-terraform-prod/strapi/ --human-readable
# Output includes both terraform.tfstate AND terraform.tfstate.tflock
```

After apply finishes or is canceled, the `.tflock` sentinel disappears within seconds.

## Conventions

- **HCL formatting:** two-space indent, `=` aligned within blocks at column 30, single blank line between resource blocks, `terraform fmt -check` clean across all `.tf`.
- **Module sources:** local relative paths only (e.g., `../../../../modules/s3`). No Terraform Registry modules.
- **Provider pin:** `hashicorp/aws = "5.91.0"` across every workspace; never use `~>` for the provider pin.
- **Terraform pin:** `required_version = "~> 1.15"` across every workspace; floor is `>= 1.10` (`use_lockfile` requirement).
- **Resource labels:** the canonical label is `"this"` (e.g., `aws_iam_role.this`). Modules expose `module.<name>.<resource>.this`.
- **Tagging:** module-level inconsistent — `sg` and `ec2` modules don't pass tags through (known anti-pattern; not blocking Phase 1/2).
- **Lifecycle locks:** CloudFront distributions, EC2 instances, and EIPs declare `prevent_destroy = true`. Removing them requires deleting the lifecycle block in a dedicated commit.
- **Secrets:** never commit secret values. Resources are created in Terraform; values are set out-of-band via `aws secretsmanager put-secret-value`.

## Roadmap

This repo is mid-migration as of 2026-05. See [`.planning/ROADMAP.md`](.planning/ROADMAP.md) for the four-phase plan:

1. **Phase 1 — Bootstrap State Backend** (in DevOps review): `bootstrap/` stack adopts `dmair-terraform-prod` via import, every live backend rewires to `use_lockfile = true`, two-terminal lock contention proves the lock works.
2. **Phase 2 — Refactor to `live/` Layout** (in DevOps review): `envs/` → `live/dmair/<env>/<component>/`, README rewrite, staging slot reserved.
3. **Phase 3 — dmair-backend Staging Slot:** `live/dmair/staging/backend/` (VPC, EC2 + EIP, RDS PostGIS, ECR, Secrets, OIDC role) deployable at `api-staging.flydmair.com`.
4. **Phase 4 — CI/CD Pipeline + OIDC:** PR-gated plans + merge-gated applies via GitHub Environments; OIDC trust + role inventory documented in `OIDC.md`.

## Cross-repo

This repo is consumed by [`dmair-backend`](https://github.com/<org>/dmair-backend) via two contracts that are expensive to rename after they land:
- DNS: `api-staging.flydmair.com` (created Phase 3).
- OIDC role ARN: name finalized in Phase 3, documented in `OIDC.md` (Phase 4).
