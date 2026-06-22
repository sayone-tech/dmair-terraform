#!/usr/bin/env bash
# One-shot ops bootstrap for a new dmair AWS environment.
# Idempotent: safe to re-run any time. Each step is a no-op if already done.
#
# Covers four out-of-band setup steps in order:
#   1. GitHub OIDC identity provider (once per AWS account)
#   2. The 3 Terraform CI IAM roles (from docs/iam-oidc/*.json)
#   3. The 4 SSM SecureString parameters at /dmair/staging/*
#   4. The dmair-backend-staging-deploy role — created only when
#      STAGING_EC2_INSTANCE_ID is exported with the real instance id,
#      because its permissions policy scopes ssm:StartSession to that
#      specific EC2 ARN. If the env var is unset (defaults to
#      PENDING_PHASE_3_APPLY), Step 4 is skipped with a hint.
#
# Run from the repo root after `export AWS_PROFILE=<write-capable>`.
# Requires: aws, jq, openssl.

set -euo pipefail

cd "$(dirname "$0")"

# ----------------------------------------------------------------------------
# 0. Verify credentials BEFORE any AWS mutation
# ----------------------------------------------------------------------------

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "Account:        $ACCOUNT_ID"
echo "Caller identity: $CALLER_ARN"
echo

TF_ORG_REPO="sayone-tech/dmair-terraform"
# Backend repo lives under the DM-Air org (github.com/DM-Air/dmair-backend). The
# GitHub OIDC token's `sub` is repo:DM-Air/dmair-backend:ref:refs/heads/staging,
# so the deploy-role trust policy MUST match this org exactly or
# configure-aws-credentials fails at deploy step 1. Do not "align" this to the
# terraform repo's org — they are different orgs.
BACKEND_ORG_REPO="DM-Air/dmair-backend"
STAGING_EC2_INSTANCE_ID="${STAGING_EC2_INSTANCE_ID:-PENDING_PHASE_3_APPLY}"
REGION=us-west-2

WORK=$(mktemp -d -t iam-oidc-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# ----------------------------------------------------------------------------
# 1. GitHub OIDC identity provider (account-wide singleton)
# ----------------------------------------------------------------------------

GITHUB_OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
echo "==> Step 1: GitHub OIDC identity provider"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$GITHUB_OIDC_ARN" >/dev/null 2>&1; then
  echo "  already registered: $GITHUB_OIDC_ARN"
else
  echo "  registering..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    >/dev/null
  echo "  created: $GITHUB_OIDC_ARN"
fi
echo

# ----------------------------------------------------------------------------
# 2. The 3 Terraform CI IAM roles + inline policies
# ----------------------------------------------------------------------------

# Render every template into $WORK with real values.
for f in docs/iam-oidc/*.json; do
  base=$(basename "$f")
  sed -e "s/ACCOUNT_ID/${ACCOUNT_ID}/g" \
      -e "s|BACKEND_ORG/BACKEND_REPO|${BACKEND_ORG_REPO}|g" \
      -e "s|ORG/REPO|${TF_ORG_REPO}|g" \
      -e "s/STAGING_EC2_INSTANCE_ID/${STAGING_EC2_INSTANCE_ID}/g" \
      "$f" > "$WORK/$base"
done

# Safety: no placeholders in the 3 Terraform CI files. The dmair-backend
# files may still contain PENDING_PHASE_3_APPLY — that's fine; we skip
# Role 4 here. They get rendered + created separately once the staging
# EC2 instance exists.
remaining=$(grep -lE "ACCOUNT_ID|ORG/REPO" \
  "$WORK"/dmair-terraform-*.json || true)
if [ -n "$remaining" ]; then
  echo "ERROR: placeholders still in:"
  echo "$remaining"
  exit 1
fi

create_role() {
  local role="$1" desc="$2"
  if aws iam get-role --role-name "$role" >/dev/null 2>&1; then
    echo "  $role: exists — updating trust policy"
    aws iam update-assume-role-policy \
      --role-name "$role" \
      --policy-document "file://$WORK/${role}-trust.json"
  else
    echo "  $role: creating"
    aws iam create-role \
      --role-name "$role" \
      --description "$desc" \
      --max-session-duration 3600 \
      --assume-role-policy-document "file://$WORK/${role}-trust.json" \
      >/dev/null
  fi
  aws iam put-role-policy \
    --role-name "$role" \
    --policy-name "$role" \
    --policy-document "file://$WORK/${role}-permissions.json"
  echo "  $role: inline policy attached"
}

echo "==> Step 2: Terraform CI roles (3)"
create_role "dmair-terraform-plan-readonly" \
  "GitHub Actions PR+push plan role (read-only)"
create_role "dmair-terraform-staging-apply" \
  "GitHub Actions manual apply for live/dmair/<comp>/staging"
create_role "dmair-terraform-prod-apply" \
  "GitHub Actions manual apply for bootstrap + prod, env-gated"
echo

# ----------------------------------------------------------------------------
# 3. SSM SecureString parameters for the 4 staging-backend sensitive values
# ----------------------------------------------------------------------------

# Idempotent: each parameter is skipped if it already exists. To rotate a
# value later, use `aws ssm put-parameter --overwrite` manually — this
# script does NOT overwrite, to avoid clobbering a real SendGrid API key
# that's been set out-of-band.

ssm_create_if_missing() {
  local name="$1" value="$2" description="$3"
  local existing
  existing=$(aws ssm describe-parameters --region "$REGION" \
    --parameter-filters "Key=Name,Values=${name}" \
    --query 'Parameters[0].Name' --output text 2>/dev/null)
  if [ "$existing" = "$name" ]; then
    echo "  ${name}: exists — skipping (use --overwrite to rotate)"
    return 0
  fi
  aws ssm put-parameter --region "$REGION" \
    --type SecureString --tier Standard \
    --name "$name" --description "$description" --value "$value" \
    >/dev/null
  echo "  ${name}: created"
}

echo "==> Step 3: SSM SecureString parameters (6)"

ssm_create_if_missing \
  "/dmair/staging/db_password" \
  "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+=' </dev/urandom | head -c 32)" \
  "RDS master/app password for dmair-staging Postgres"

ssm_create_if_missing \
  "/dmair/staging/jwt_secret_key" \
  "$(openssl rand -hex 64)" \
  "HS512 JWT signing key for dmair-backend staging"

ssm_create_if_missing \
  "/dmair/staging/mail_password" \
  "PENDING_REPLACE_WITH_SENDGRID_API_KEY" \
  "SendGrid API key for transactional email — REPLACE before app deploy"

ssm_create_if_missing \
  "/dmair/staging/admin_bootstrap_password" \
  "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+=' </dev/urandom | head -c 24)" \
  "Initial admin bootstrap password for dmair-backend staging"

# Phase 13 ingest (Google OAuth). ssm.tf reads these as data sources, so they
# MUST exist before `terraform plan` on live/dmair/backend/staging. Seeded as
# REPLACE placeholders here; rotate with the real Google OAuth client
# credentials (the SAME OAuth client used by local-dev) via:
#   aws ssm put-parameter --overwrite --type SecureString --region us-west-2 \
#     --name /dmair/staging/ingest_oauth_google_client_id     --value "<client-id>"
#   aws ssm put-parameter --overwrite --type SecureString --region us-west-2 \
#     --name /dmair/staging/ingest_oauth_google_client_secret --value "<client-secret>"
ssm_create_if_missing \
  "/dmair/staging/ingest_oauth_google_client_id" \
  "PENDING_REPLACE_WITH_GOOGLE_OAUTH_CLIENT_ID" \
  "Google OAuth client id for ingest mailbox — REPLACE before app deploy"

ssm_create_if_missing \
  "/dmair/staging/ingest_oauth_google_client_secret" \
  "PENDING_REPLACE_WITH_GOOGLE_OAUTH_CLIENT_SECRET" \
  "Google OAuth client secret for ingest mailbox — REPLACE before app deploy"

echo

# ----------------------------------------------------------------------------
# 4. dmair-backend-staging-deploy role (needs EC2 instance ID)
# ----------------------------------------------------------------------------

# The sibling dmair-backend repo's CI uses this role to push images to ECR
# and restart the systemd unit on the staging EC2. Its permissions policy
# pins ssm:StartSession + ssm:SendCommand to the specific EC2 instance ARN,
# so we can only create it after live/dmair/backend/staging has been applied.

echo "==> Step 4: dmair-backend-staging-deploy role"
if [ "$STAGING_EC2_INSTANCE_ID" = "PENDING_PHASE_3_APPLY" ]; then
  echo "  skipped — STAGING_EC2_INSTANCE_ID not set."
  echo "  Run again with: STAGING_EC2_INSTANCE_ID=i-xxxxx $0"
else
  # Re-validate the rendered templates now that we expect real values.
  if grep -lE "PENDING_PHASE_3_APPLY|STAGING_EC2_INSTANCE_ID" \
      "$WORK"/dmair-backend-staging-deploy-*.json >/dev/null; then
    echo "ERROR: placeholders still in dmair-backend-staging-deploy templates"
    echo "  ensure STAGING_EC2_INSTANCE_ID is a real EC2 id (e.g. i-0abc...)"
    exit 1
  fi
  create_role "dmair-backend-staging-deploy" \
    "GitHub Actions OIDC deploy role for sibling dmair-backend repo (staging)"
fi
echo

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

echo "=========================================================="
echo "  Bootstrap complete"
echo "=========================================================="
echo
echo "GitHub OIDC provider ARN:"
echo "  $GITHUB_OIDC_ARN"
echo
echo "Terraform CI role ARNs (set as repo Secrets):"
for role in dmair-terraform-plan-readonly \
            dmair-terraform-staging-apply \
            dmair-terraform-prod-apply; do
  arn=$(aws iam get-role --role-name "$role" --query 'Role.Arn' --output text)
  printf "  %-40s %s\n" "$role" "$arn"
done
echo
echo "Repo Secrets to set (Settings → Secrets and variables → Actions):"
echo "  AWS_PLAN_ROLE_ARN           = <plan-readonly ARN above>"
echo "  AWS_STAGING_APPLY_ROLE_ARN  = <staging-apply ARN above>"
echo "  AWS_PROD_APPLY_ROLE_ARN     = <prod-apply ARN above>"
echo
if [ "$STAGING_EC2_INSTANCE_ID" != "PENDING_PHASE_3_APPLY" ]; then
  echo "Sibling dmair-backend repo Secret to set:"
  backend_arn=$(aws iam get-role --role-name dmair-backend-staging-deploy \
    --query 'Role.Arn' --output text 2>/dev/null)
  echo "  AWS_DEPLOY_ROLE_ARN         = $backend_arn"
  echo "  (Settings → Secrets and variables → Actions in the dmair-backend repo)"
  echo
fi
echo "SSM parameter inventory:"
aws ssm describe-parameters --region "$REGION" \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=/dmair/staging/" \
  --query 'Parameters[].Name' --output text \
  | tr '\t' '\n' | sed 's/^/  /'
echo
echo "Pending manual ops (NOT covered by this script):"
echo "  - Rotate /dmair/staging/mail_password with a real SendGrid API key:"
echo "    aws ssm put-parameter --overwrite --type SecureString --region $REGION \\"
echo "      --name /dmair/staging/mail_password --value '<real-api-key>'"
echo "    (outbound email — activation/reset — fails until replaced)"
echo "  - Rotate the two ingest OAuth placeholders with the real Google OAuth"
echo "    client (same client as local-dev): /dmair/staging/ingest_oauth_google_client_id"
echo "    and /dmair/staging/ingest_oauth_google_client_secret (use --overwrite)"
echo "  - Configure 'prod' GitHub Environment with required reviewers"
echo "    (Settings → Environments → New environment → prod)"
echo "  - Enable branch protection on main, require 'terraform / Detect changed stacks'"
if [ "$STAGING_EC2_INSTANCE_ID" = "PENDING_PHASE_3_APPLY" ]; then
  echo "  - After Phase 3 apply, create the dmair-backend-staging-deploy role"
  echo "    (re-run this script with STAGING_EC2_INSTANCE_ID=i-... exported)"
fi
