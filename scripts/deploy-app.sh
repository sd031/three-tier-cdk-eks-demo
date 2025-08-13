#!/bin/bash

# Script to deploy the 3-tier application to EKS
set -e

CLUSTER_NAME=$1
REGION=$2
DB_SECRET_ARN=$3

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ] || [ -z "$DB_SECRET_ARN" ]; then
    echo "Usage: $0 <cluster-name> <region> <db-secret-arn>"
    echo "Example: $0 ThreeTierEksStack-ThreeTierCluster us-west-2 arn:aws:secretsmanager:us-west-2:123456789012:secret:..."
    exit 1
fi

echo "Deploying 3-tier application to cluster: $CLUSTER_NAME"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Get database credentials from AWS Secrets Manager
echo "Retrieving database credentials..."
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET_ARN --region $REGION --query SecretString --output text)
DB_HOST=$(echo $DB_SECRET | jq -r .host)
DB_USER=$(echo $DB_SECRET | jq -r .username)
DB_PASSWORD=$(echo $DB_SECRET | jq -r .password)

# Encode credentials in base64
DB_HOST_B64=$(echo -n $DB_HOST | base64)
DB_USER_B64=$(echo -n $DB_USER | base64)
DB_PASSWORD_B64=$(echo -n $DB_PASSWORD | base64)

# Create temporary secret file with actual values
cat > temp-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  namespace: three-tier-app
type: Opaque
data:
  DB_HOST: $DB_HOST_B64
  DB_NAME: dGhyZWV0aWVyZGI=
  DB_USER: $DB_USER_B64
  DB_PASSWORD: $DB_PASSWORD_B64
EOF

# Apply Kubernetes manifests
echo "Creating namespace..."
kubectl apply -f ../k8s-manifests/namespace.yaml

echo "Creating database secret..."
kubectl apply -f temp-secret.yaml

echo "Deploying backend application..."
kubectl apply -f ../k8s-manifests/backend-deployment.yaml

echo "Deploying frontend application..."
kubectl apply -f ../k8s-manifests/frontend-deployment.yaml

echo "Creating ingress..."
kubectl apply -f ../k8s-manifests/ingress.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend-api -n three-tier-app
kubectl wait --for=condition=available --timeout=300s deployment/frontend-app -n three-tier-app

# Get ingress URL
echo "Getting application URL..."
sleep 30  # Wait for ALB to be provisioned
INGRESS_URL=$(kubectl get ingress three-tier-ingress -n three-tier-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Deployment complete!"
echo "Application URL: http://$INGRESS_URL"
echo ""
echo "You can check the status with:"
echo "kubectl get pods -n three-tier-app"
echo "kubectl get services -n three-tier-app"
echo "kubectl get ingress -n three-tier-app"

# Clean up temporary file
rm temp-secret.yaml

echo "Done!"
