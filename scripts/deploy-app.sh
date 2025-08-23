#!/bin/bash

# Script to deploy the 3-tier application with in-cluster PostgreSQL to EKS
set -e

CLUSTER_NAME=$1
REGION=$2

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ]; then
    echo "Usage: $0 <cluster-name> <region>"
    echo "Example: $0 ThreeTierEksStack-ThreeTierCluster us-west-2"
    exit 1
fi

echo "Deploying 3-tier application with PostgreSQL to cluster: $CLUSTER_NAME"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../k8s-manifests"

# Apply Kubernetes manifests in the correct order
echo "Creating namespace..."
kubectl apply -f "$MANIFEST_DIR/namespace.yaml"

echo "Creating PostgreSQL secrets..."
kubectl apply -f "$MANIFEST_DIR/postgres-secret.yaml"

echo "Deploying PostgreSQL database..."
kubectl apply -f "$MANIFEST_DIR/postgres-deployment.yaml"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n todo-app --timeout=300s

# Verify PostgreSQL is accepting connections
echo "Verifying PostgreSQL connectivity..."
kubectl exec -n todo-app deployment/postgres -- pg_isready -U postgres

echo "Deploying backend application..."
kubectl apply -f "$MANIFEST_DIR/backend-deployment.yaml"

echo "Deploying frontend application..."
kubectl apply -f "$MANIFEST_DIR/frontend-deployment.yaml"

echo "Creating ingress..."
kubectl apply -f "$MANIFEST_DIR/ingress.yaml"

# Wait for application deployments to be ready
echo "Waiting for application deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backend-api -n todo-app
kubectl wait --for=condition=available --timeout=300s deployment/frontend-app -n todo-app

# Get ingress URL
echo "Getting application URL..."
echo "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
sleep 60  # Wait for ALB to be provisioned

# Try to get the ingress URL with retries
for i in {1..10}; do
    INGRESS_URL=$(kubectl get ingress todo-ingress -n todo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_URL" ]; then
        break
    fi
    echo "Waiting for ALB URL... (attempt $i/10)"
    sleep 30
done

echo ""
echo "🎉 Deployment complete!"
echo ""
if [ -n "$INGRESS_URL" ]; then
    echo "📱 Application URL: http://$INGRESS_URL"
else
    echo "⚠️  ALB URL not yet available. Check ingress status:"
    echo "   kubectl get ingress todo-ingress -n todo-app"
fi
echo ""
echo "📊 Check deployment status:"
echo "   kubectl get pods -n todo-app"
echo "   kubectl get services -n todo-app"
echo "   kubectl get ingress -n todo-app"
echo ""
echo "🗄️  Connect to PostgreSQL:"
echo "   kubectl exec -it deployment/postgres -n todo-app -- psql -U postgres -d tododb"
echo ""
echo "📋 View logs:"
echo "   kubectl logs -f deployment/postgres -n todo-app"
echo "   kubectl logs -f deployment/backend-api -n todo-app"
echo "   kubectl logs -f deployment/frontend-app -n todo-app"
echo ""
echo "✅ Done!"
