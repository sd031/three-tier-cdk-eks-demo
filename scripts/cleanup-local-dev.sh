#!/bin/bash

# Cleanup script for local development environment
set -e

echo "🧹 Cleaning up Todo App Local Development Environment"

# Stop Skaffold if running
echo "🛑 Stopping Skaffold (if running)..."
pkill -f "skaffold dev" || true

# Delete Skaffold deployments
echo "🗑️  Cleaning up Skaffold deployments..."
skaffold delete || true

# Delete KinD cluster
echo "🔥 Deleting KinD cluster..."
if kind get clusters | grep -q "todo-app-cluster"; then
    kind delete cluster --name todo-app-cluster
    echo "✅ KinD cluster deleted successfully"
else
    echo "📝 KinD cluster 'todo-app-cluster' does not exist"
fi

# Clean up Docker images (optional)
read -p "🐳 Do you want to clean up Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧽 Cleaning up Docker images..."
    docker image prune -f
    docker rmi todo-backend todo-frontend 2>/dev/null || true
    echo "✅ Docker images cleaned up"
fi

echo "✅ Cleanup complete!"
