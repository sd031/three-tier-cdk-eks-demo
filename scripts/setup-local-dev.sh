#!/bin/bash

# Setup script for local development with KinD and Skaffold
set -e

echo "🚀 Setting up Todo App Local Development Environment"

# Check if required tools are installed
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    else
        echo "✅ $1 is installed"
    fi
}

echo "📋 Checking required tools..."
check_tool docker
check_tool kind
check_tool kubectl
check_tool skaffold

# Create KinD cluster
echo "🔧 Creating KinD cluster..."
if kind get clusters | grep -q "todo-app-cluster"; then
    echo "📝 KinD cluster 'todo-app-cluster' already exists"
else
    kind create cluster --config kind-config.yaml
    echo "✅ KinD cluster created successfully"
fi

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install NGINX Ingress Controller
echo "🌐 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "✅ Local development environment setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Run 'skaffold dev' to start the application"
echo "2. Access the app at http://localhost:8080"
echo "3. Make changes to your code and see them reflected automatically"
echo ""
echo "🛠️  Useful commands:"
echo "- skaffold dev          # Start development mode with hot reload"
echo "- skaffold run          # Deploy once without watching for changes"
echo "- skaffold delete       # Clean up deployed resources"
echo "- kind delete cluster --name todo-app-cluster  # Delete the cluster"
