# live/dmair/staging/

Staging-environment slot for the `dmair` project. Currently contains:

- `frontend/` — staging frontend stack (`staging.flydmair.com`), already live.

Reserved (created in Phase 3):

- `backend/` — dmair-backend staging stack (`api-staging.flydmair.com`). VPC + EC2 + Elastic IP + RDS PostGIS + ECR + Secrets Manager + CloudWatch + AWS Budget alarm + OIDC role for `dmair-backend` CI. See [`.planning/ROADMAP.md`](../../../.planning/ROADMAP.md) §Phase 3 for goal/criteria.

Until Phase 3 lands, `backend/` does not exist. This README is the contract reserving the path so `dmair-backend` CI can stop wondering where its staging slot will live.

## Conventions

Stacks under `live/dmair/staging/` share the same conventions as the rest of the repo:

- Each component is a separate Terraform workspace with its own `backend.tf` (S3-native locking via `use_lockfile = true`).
- State keys use the `staging/<component>/terraform.tfstate` shape (e.g., `staging/frontend/terraform.tfstate`, `staging/backend/terraform.tfstate`).
- All AWS resources are pinned to `us-west-2`.
- AWS provider is pinned at `hashicorp/aws 5.91.0` across the repo.
- Module sources are local (`../../../../modules/...`) — no Terraform Registry modules.

## Cross-repo contract

The slot at `live/dmair/staging/backend/` is the staging deployment target for the sibling [`dmair-backend`](https://github.com/<org>/dmair-backend) repository. The OIDC role that `dmair-backend` CI assumes is scoped to read/write **only** under `live/dmair/staging/*` — it cannot reach `live/dmair/prod/*` or any pre-existing `cms-*` / `frontend-*` resource in the shared account (deny-by-exclusion verified in Phase 3 STAGING-03).
