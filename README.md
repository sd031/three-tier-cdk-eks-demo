# Todo App - 3-Tier Application on Amazon EKS with AWS CDK

This project demonstrates how to deploy a complete 3-tier Todo application on Amazon EKS (Elastic Kubernetes Service) using AWS CDK (Cloud Development Kit) with TypeScript. Features both local development with KinD/Skaffold and production deployment on EKS Auto Mode with in-cluster PostgreSQL database.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Presentation   │    │   Application   │    │      Data       │
│     Tier        │    │      Tier       │    │      Tier       │
│                 │    │                 │    │                 │
│   Todo Frontend │◄──►│   Todo API      │◄──►│   PostgreSQL    │
│   (HTML/CSS/JS) │    │   (Node.js)     │    │   (In-Cluster)  │
│                 │    │                 │    │                 │
│   EKS Auto Mode │    │   EKS Auto Mode │    │   EKS Auto Mode │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   AWS Load      │
                    │   Balancer      │
                    │   (ALB)         │
                    └─────────────────┘
```

## Components

### Infrastructure (AWS CDK)
- **VPC**: Multi-AZ VPC with public, private, and database subnets
- **EKS Auto Mode Cluster**: Fully managed Kubernetes cluster with automatic compute, networking, and storage management
- **PostgreSQL Database**: In-cluster PostgreSQL with persistent storage
- **Security Groups**: Proper network isolation and access control
- **IAM Roles**: Service accounts and permissions for AWS Load Balancer Controller

### Application Tiers
1. **Presentation Tier**: Todo Frontend (HTML/CSS/JavaScript) served by Nginx in Docker container
2. **Application Tier**: Todo API (Node.js/Express) with full CRUD operations in Docker container
3. **Data Tier**: PostgreSQL database running in EKS cluster with persistent volumes

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Tools
- **AWS CLI v2**: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **AWS CDK**: Install globally with `npm install -g aws-cdk`
- **Node.js 18+**: [Download Node.js](https://nodejs.org/)
- **TypeScript**: Install globally with `npm install -g typescript`
- **kubectl**: [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **jq**: JSON processor for shell scripts

### AWS Configuration
```bash
# Configure AWS credentials
aws configure

# Verify your configuration
aws sts get-caller-identity
```

### Install Required Tools (macOS)
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install awscli
brew install kubectl
brew install jq
npm install -g aws-cdk

# Verify installations
aws --version
cdk --version
kubectl version --client
jq --version
```

## Step-by-Step Deployment Guide

### Step 1: Clone and Setup the Project

```bash
# Navigate to the project directory
cd /Users/sandipdas/cdk_eks

# Navigate to the CDK TypeScript project
cd cdk-eks-typescript

# Install TypeScript dependencies
npm install
```

### Step 2: Bootstrap AWS CDK (First-time setup)

```bash
# Bootstrap CDK in your AWS account and region
cdk bootstrap

# This creates the necessary S3 bucket and IAM roles for CDK deployments
```

### Step 3: Review and Customize the Infrastructure

The main infrastructure code is in `cdk-eks-typescript/lib/cdk-eks-typescript-stack.ts`. Key components:

- **VPC Configuration**: 3 AZs with public, private, and database subnets
- **EKS Auto Mode Cluster**: Kubernetes v1.32 with automatic compute management (no manual node groups needed)
- **In-Cluster Database**: PostgreSQL 15 with persistent volumes and secrets management
- **Security**: Proper security groups and IAM roles

### Step 4: Deploy the Infrastructure

```bash
# Navigate to the CDK TypeScript directory
cd cdk-eks-typescript

# Synthesize the CloudFormation template (optional - for review)
cdk synth

# Deploy the infrastructure
cdk deploy

# This will take approximately 15-20 minutes
# You'll be prompted to approve IAM changes - type 'y' to proceed
```

**Expected Output:**
```
✅  ThreeTierEksStack

Outputs:
ThreeTierEksStack.ClusterName = ThreeTierEksStack-ThreeTierCluster12345678
ThreeTierEksStack.EksClusterEndpoint = https://ABC123DEF456.gr7.us-west-2.eks.amazonaws.com
ThreeTierEksStack.VpcId = vpc-0123456789abcdef0
```

### Step 5: Install AWS Load Balancer Controller

```bash
# Get the cluster name and region from CDK outputs
CLUSTER_NAME="ThreeTierEksStack-ThreeTierCluster12345678"  # Replace with your actual cluster name
REGION="us-west-2"  # Replace with your region

# Run the installation script
./scripts/install-alb-controller.sh $CLUSTER_NAME $REGION
```

**What this script does:**
1. Updates your kubeconfig to connect to the EKS cluster
2. Installs cert-manager (required for ALB controller)
3. Installs AWS Load Balancer Controller
4. Configures the controller to work with your cluster

### Step 6: Deploy the 3-Tier Application

```bash
# Update kubeconfig to connect to your EKS cluster
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Deploy the database first
kubectl apply -f k8s-manifests/namespace.yaml
kubectl apply -f k8s-manifests/postgres-secret.yaml
kubectl apply -f k8s-manifests/postgres-deployment.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n todo-app --timeout=300s

# Deploy the application
kubectl apply -f k8s-manifests/backend-deployment.yaml
kubectl apply -f k8s-manifests/frontend-deployment.yaml
kubectl apply -f k8s-manifests/ingress.yaml
```

**What this does:**
1. Creates Kubernetes namespace and database secrets
2. Deploys PostgreSQL database with persistent storage
3. Deploys backend API (Node.js/Express)
4. Deploys frontend application (HTML/Nginx)
5. Creates Application Load Balancer ingress
6. Provides the application URL

### Step 7: Verify the Deployment

```bash
# Check pod status
kubectl get pods -n todo-app

# Check services
kubectl get services -n todo-app

# Check ingress and get the URL
kubectl get ingress -n todo-app

# View application logs
kubectl logs -f deployment/backend-api -n todo-app
kubectl logs -f deployment/frontend-app -n todo-app
kubectl logs -f deployment/postgres -n todo-app
```

**Expected Pod Status:**
```
NAME                           READY   STATUS    RESTARTS   AGE
postgres-7d4b8c9f8d-abc12      1/1     Running   0          8m
backend-api-7d4b8c9f8d-def34   1/1     Running   0          5m
backend-api-7d4b8c9f8d-ghi56   1/1     Running   0          5m
frontend-app-6b7c8d9e0f-jkl78  1/1     Running   0          5m
frontend-app-6b7c8d9e0f-mno90  1/1     Running   0          5m
```

### Step 8: Access the Application

After deployment, you'll receive an Application Load Balancer URL:

```
Application URL: http://k8s-threetie-threetie-1234567890-1234567890.us-west-2.elb.amazonaws.com
```

Open this URL in your browser to access the 3-tier application.

## Application Features

### Backend API Endpoints
- `GET /health` - Health check endpoint
- `GET /api/todos` - Retrieve all todos
- `GET /api/todos/:id` - Get specific todo
- `POST /api/todos` - Create a new todo
- `PUT /api/todos/:id` - Update a todo
- `DELETE /api/todos/:id` - Delete a todo
- `PATCH /api/todos/:id/toggle` - Toggle completion status

### Database Schema
```sql
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

**Happy Deploying! 🚀**
