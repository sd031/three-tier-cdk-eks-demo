#!/bin/bash

# Script to destroy the CDK EKS stack and associated AWS resources
set -euo pipefail

echo "🧨 Destroying EKS CDK Stack..."

# Get current user ARN (for consistent context, though not required for destroy)
echo "Getting current user ARN..."
CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "Current user ARN: $CURRENT_USER_ARN"

# Navigate to CDK directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CDK_DIR="$SCRIPT_DIR/../cdk-eks-typescript"
cd "$CDK_DIR"

# Determine stack name: use first arg or default to the first stack from `cdk ls`
STACK_NAME=${1:-}
if [ -z "$STACK_NAME" ]; then
  echo "Detecting stack name from 'cdk ls'..."
  STACK_NAME=$(cdk ls | head -n 1)
fi

if [ -z "$STACK_NAME" ]; then
  echo "❌ Could not determine a stack name. Pass it explicitly:"
  echo "   $0 <stack-name>"; exit 1
fi

# Confirm
read -p "⚠️  This will permanently delete stack '$STACK_NAME' and all managed resources. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."; exit 0
fi

# Destroy
echo "Destroying CDK stack '$STACK_NAME'..."
cdk destroy "$STACK_NAME" \
  --context deployerArn="$CURRENT_USER_ARN" \
  --force

echo "✅ CDK destroy complete for stack: $STACK_NAME"
