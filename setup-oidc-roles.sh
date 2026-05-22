#!/usr/bin/env bash
# One-shot ops bootstrap for a new dmair AWS environment.
# Idempotent: safe to re-run any time. Each step is a no-op if already done.
#
# Covers four out-of-band setup steps in order:
#   1. GitHub OIDC identity provider (once per AWS account)
#   2. The 3 Terraform CI IAM roles (from docs/iam-oidc/*.json)
#   3. The 4 SSM SecureString parameters at /dmair/staging/*
#   4. (NOT covered, manual) the dmair-backend-staging-deploy role
#      because it needs the EC2 instance ID — deferred until after
#      live/dmair/backend/staging has been terraform-applied.
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
BACKEND_ORG_REPO="sayone-tech/dmair-backend"
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

echo "==> Step 3: SSM SecureString parameters (4)"

ssm_create_if_missing \
  "/dmair/staging/db_password" \
  "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+-=' </dev/urandom | head -c 32)" \
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
  "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%^&*_+-=' </dev/urandom | head -c 24)" \
  "Initial admin bootstrap password for dmair-backend staging"

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
echo "  - Configure 'prod' GitHub Environment with required reviewers"
echo "    (Settings → Environments → New environment → prod)"
echo "  - Enable branch protection on main, require 'terraform / Detect changed stacks'"
echo "  - After Phase 3 apply, create the dmair-backend-staging-deploy role"
echo "    (re-run this script with STAGING_EC2_INSTANCE_ID=i-... exported)"
