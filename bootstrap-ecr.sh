#!/usr/bin/env bash
# bootstrap-ecr.sh
#
# One-time setup: creates the ECR repository the app's Docker image gets
# pushed to. This has to exist *before* the first image push (Step 3),
# and before it gets imported into Terraform's state in Step 5 — so it
# can't be created by Terraform itself on a first-time setup.
#
# Usage: chmod +x bootstrap-ecr.sh && ./bootstrap-ecr.sh

set -euo pipefail

REPO_NAME="ecs-project-tracker"
REGION="eu-west-2"

echo "Checking if ECR repository '$REPO_NAME' already exists..."

if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "Repository '$REPO_NAME' already exists — nothing to do."
else
  echo "Creating ECR repository '$REPO_NAME' in $REGION..."
  aws ecr create-repository \
    --repository-name "$REPO_NAME" \
    --region "$REGION" \
    --image-scanning-configuration scanOnPush=true

  echo "Done. Repository URI:"
  aws ecr describe-repositories \
    --repository-names "$REPO_NAME" \
    --region "$REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text
fi

echo ""
echo "Next: build and push your image, then run 'terraform import module.ecr.aws_ecr_repository.this $REPO_NAME' before your first terraform apply."