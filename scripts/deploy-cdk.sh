#!/bin/bash

# Script to deploy CDK stack with current user access
set -e

echo "🚀 Deploying EKS CDK Stack with current user access..."

# Get current user ARN
echo "Getting current user ARN..."
CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "Current deployer ARN: $CURRENT_USER_ARN"

# Navigate to CDK directory
cd "$(dirname "$0")/../cdk-eks-typescript"

# Deploy with current user ARN as context
echo "Deploying CDK stack..."
cdk deploy --context deployerArn="$CURRENT_USER_ARN" --require-approval never

echo "✅ CDK deployment complete!"
echo "Current user ($CURRENT_USER_ARN) now has admin access to the EKS cluster."
