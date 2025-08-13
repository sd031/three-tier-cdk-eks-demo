#!/bin/bash

# Script to install AWS Load Balancer Controller on EKS
set -e

CLUSTER_NAME=$1
REGION=$2

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ]; then
    echo "Usage: $0 <cluster-name> <region>"
    echo "Example: $0 ThreeTierEksStack-ThreeTierCluster us-west-2"
    exit 1
fi

echo "Installing AWS Load Balancer Controller for cluster: $CLUSTER_NAME in region: $REGION"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Download ALB controller manifest
echo "Downloading AWS Load Balancer Controller manifest..."
curl -o alb-controller.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.5.4/v2_5_4_full.yaml

# Replace cluster name in the manifest
sed -i.bak "s/your-cluster-name/$CLUSTER_NAME/g" alb-controller.yaml

# Apply the manifest
echo "Installing AWS Load Balancer Controller..."
kubectl apply -f alb-controller.yaml

# Wait for the controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

echo "AWS Load Balancer Controller installed successfully!"

# Clean up
rm alb-controller.yaml alb-controller.yaml.bak

echo "Installation complete!"
