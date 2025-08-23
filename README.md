# Todo App - 3-Tier Application on Amazon EKS with AWS CDK

This project demonstrates how to deploy a complete 3-tier Todo application on Amazon EKS (Elastic Kubernetes Service) using AWS CDK (Cloud Development Kit) with Python. Features both local development with KinD/Skaffold and production deployment on EKS Auto Mode.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Presentation   │    │   Application   │    │      Data       │
│     Tier        │    │      Tier       │    │      Tier       │
│                 │    │                 │    │                 │
│   Todo Frontend │◄──►│   Todo API      │◄──►│   PostgreSQL    │
│   (HTML/CSS/JS) │    │   (Node.js)     │    │     (RDS)       │
│                 │    │                 │    │                 │
│   EKS Auto Mode │    │   EKS Auto Mode │    │   RDS Instance  │
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
- **RDS PostgreSQL**: Managed database in private subnets
- **Security Groups**: Proper network isolation and access control
- **IAM Roles**: Service accounts and permissions for AWS Load Balancer Controller

### Application Tiers
1. **Presentation Tier**: Todo Frontend (HTML/CSS/JavaScript) served by Nginx in Docker container
2. **Application Tier**: Todo API (Node.js/Express) with full CRUD operations in Docker container
3. **Data Tier**: PostgreSQL database on Amazon RDS

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Tools
- **AWS CLI v2**: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **AWS CDK**: Install globally with `npm install -g aws-cdk`
- **Python 3.8+**: [Download Python](https://www.python.org/downloads/)
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

# Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt
```

### Step 2: Bootstrap AWS CDK (First-time setup)

```bash
# Bootstrap CDK in your AWS account and region
cdk bootstrap

# This creates the necessary S3 bucket and IAM roles for CDK deployments
```

### Step 3: Review and Customize the Infrastructure

The main infrastructure code is in `three_tier_eks/three_tier_eks_stack.py`. Key components:

- **VPC Configuration**: 3 AZs with public, private, and database subnets
- **EKS Auto Mode Cluster**: Kubernetes v1.30 with automatic compute management (no manual node groups needed)
- **RDS Database**: PostgreSQL 15.3 with automated backups
- **Security**: Proper security groups and IAM roles

### Step 4: Deploy the Infrastructure

```bash
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
ThreeTierEksStack.DatabaseEndpoint = database-instance.abc123.us-west-2.rds.amazonaws.com
ThreeTierEksStack.DatabaseSecretArn = arn:aws:secretsmanager:us-west-2:123456789012:secret:...
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
# Get the database secret ARN from CDK outputs
DB_SECRET_ARN="arn:aws:secretsmanager:us-west-2:123456789012:secret:..."  # Replace with your actual ARN

# Deploy the application
./scripts/deploy-app.sh $CLUSTER_NAME $REGION $DB_SECRET_ARN
```

**What this script does:**
1. Retrieves database credentials from AWS Secrets Manager
2. Creates Kubernetes namespace and secrets
3. Deploys backend API (Node.js/Express)
4. Deploys frontend application (HTML/Nginx)
5. Creates Application Load Balancer ingress
6. Provides the application URL

### Step 7: Verify the Deployment

```bash
# Check pod status
kubectl get pods -n three-tier-app

# Check services
kubectl get services -n three-tier-app

# Check ingress and get the URL
kubectl get ingress -n three-tier-app

# View application logs
kubectl logs -f deployment/backend-api -n three-tier-app
kubectl logs -f deployment/frontend-app -n three-tier-app
```

**Expected Pod Status:**
```
NAME                           READY   STATUS    RESTARTS   AGE
backend-api-7d4b8c9f8d-abc12   1/1     Running   0          5m
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

The deployed Todo application includes:

### Frontend Features
- **Modern UI**: Bootstrap-based responsive design with gradient styling
- **Real-time Status**: Backend connectivity indicator
- **Todo Management**: Full CRUD operations (Create, Read, Update, Delete)
- **Filter Options**: View All, Completed, or Pending todos
- **Auto-refresh**: Periodic updates every 30 seconds
- **Responsive Design**: Works on desktop and mobile devices

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

## Local Development

For local development and testing, this project includes a complete setup with KinD (Kubernetes in Docker) and Skaffold:

### Quick Start - Local Development

```bash
# Setup local Kubernetes cluster
./scripts/setup-local-dev.sh

# Start development mode with hot reload
skaffold dev

# Access the application
# Frontend: http://localhost:8080
# Backend API: http://localhost:3000
# Database: localhost:5432
```

See [LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md) for detailed local development instructions.

## Monitoring and Troubleshooting

### Common Commands

```bash
# View all resources in the application namespace
kubectl get all -n three-tier-app

# Check pod logs
kubectl logs -f deployment/backend-api -n three-tier-app
kubectl logs -f deployment/frontend-app -n three-tier-app

# Describe a pod for troubleshooting
kubectl describe pod <pod-name> -n three-tier-app

# Check ingress status
kubectl describe ingress three-tier-ingress -n three-tier-app

# Connect to the database (from a pod)
kubectl exec -it deployment/backend-api -n three-tier-app -- /bin/sh
```

### Database Connection Testing

```bash
# Get database credentials
aws secretsmanager get-secret-value --secret-id <SECRET_ARN> --region <REGION>

# Test connection from a backend pod
kubectl exec -it deployment/backend-api -n three-tier-app -- node -e "
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 5432,
});
pool.query('SELECT * FROM todos LIMIT 5', (err, res) => {
  if (err) console.error(err);
  else console.log('Connected. Sample todos:', res.rows);
  process.exit(0);
});
"
```

### Scaling the Application

With EKS Auto Mode, scaling is handled automatically, but you can also manually scale:

```bash
# Scale backend pods
kubectl scale deployment backend-api --replicas=5 -n three-tier-app

# Scale frontend pods
kubectl scale deployment frontend-app --replicas=3 -n three-tier-app

# EKS Auto Mode will automatically provision nodes as needed
# Check pod status
kubectl get pods -n three-tier-app -w
```

## Security Best Practices

This deployment implements several security best practices:

1. **Network Isolation**: 
   - Database in isolated subnets
   - Application in private subnets
   - Load balancer in public subnets

2. **Access Control**:
   - Security groups restrict database access to VPC only
   - IAM roles with least privilege principles
   - Kubernetes RBAC for service accounts

3. **Secrets Management**:
   - Database credentials stored in AWS Secrets Manager
   - Kubernetes secrets for application configuration

4. **Encryption**:
   - RDS encryption at rest
   - EKS encryption for etcd and secrets

## Cost Optimization

### Resource Sizing
- **EKS Auto Mode**: Automatic scaling from 0-1000 nodes (m5.large, m5.xlarge, m4.large)
- **RDS Instance**: t3.micro (1 vCPU, 1GB RAM)
- **Load Balancer**: Application Load Balancer (pay per use)

### Cost Monitoring
```bash
# Check resource utilization
kubectl top nodes
kubectl top pods -n three-tier-app

# View AWS costs in the console or use AWS CLI
aws ce get-cost-and-usage --time-period Start=2023-01-01,End=2023-01-31 --granularity MONTHLY --metrics BlendedCost
```

## Project Structure

```
├── app.py                           # CDK app entry point (Python)
├── requirements.txt                 # Python dependencies
├── cdk.json                        # CDK configuration
├── three_tier_eks/
│   ├── __init__.py
│   └── three_tier_eks_stack.py     # EKS Auto Mode stack
├── backend/                        # Todo API (Docker)
│   ├── server.js                   # Node.js/Express server
│   ├── package.json               # Dependencies
│   └── Dockerfile                 # Backend container
├── frontend/                       # Todo Frontend (Docker)
│   ├── index.html                 # Todo UI
│   ├── nginx.conf                 # Nginx configuration
│   └── Dockerfile                 # Frontend container
├── k8s-manifests/                  # AWS EKS manifests
│   ├── namespace.yaml
│   ├── database-secret.yaml
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   └── ingress.yaml
├── k8s-local/                      # Local development manifests
│   ├── namespace.yaml
│   ├── postgres.yaml
│   ├── backend.yaml
│   ├── frontend.yaml
│   └── ingress.yaml
├── scripts/                        # Deployment scripts
│   ├── setup-local-dev.sh
│   ├── cleanup-local-dev.sh
│   ├── install-alb-controller.sh
│   └── deploy-app.sh
├── skaffold.yaml                   # Local development workflow
├── kind-config.yaml               # Local Kubernetes cluster
└── LOCAL_DEVELOPMENT.md           # Local dev guide
```

## Cleanup

To avoid ongoing AWS charges, clean up the resources:

### Local Development Cleanup
```bash
# Stop local development
./scripts/cleanup-local-dev.sh
```

### AWS Resources Cleanup
```bash
# Delete the Kubernetes application
kubectl delete namespace three-tier-app

# Delete the CDK stack (this will remove all AWS resources)
cdk destroy

# Confirm deletion when prompted
```

**Warning**: This will permanently delete all resources including the database. Make sure to backup any important data first.

## Troubleshooting Guide

### Common Issues

#### 1. CDK Bootstrap Issues
```bash
# If bootstrap fails, try specifying the region explicitly
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

#### 2. EKS Access Issues
```bash
# Update kubeconfig if you can't access the cluster
aws eks update-kubeconfig --region REGION --name CLUSTER-NAME

# Check if you have the right permissions
kubectl auth can-i "*" "*"
```

#### 3. ALB Controller Issues
```bash
# Check ALB controller logs
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system

# Verify service account annotations
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
```

#### 4. Database Connection Issues
```bash
# Check if database is accessible from pods
kubectl exec -it deployment/backend-api -n three-tier-app -- nslookup $DB_HOST

# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

#### 5. Application Not Loading
```bash
# Check ingress status
kubectl get ingress -n three-tier-app

# Verify ALB is created
aws elbv2 describe-load-balancers

# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...
```

## Advanced Configurations

### Enable HTTPS
To enable HTTPS, modify the ingress annotation:

```yaml
annotations:
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/certificate-id
```

### Add Monitoring
Deploy Prometheus and Grafana:

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### Database Backup
Configure automated backups:

```python
# In the CDK stack, modify the RDS instance
backup_retention=rds.BackupProps(
    retention=30,  # Keep backups for 30 days
    preferred_backup_window="03:00-04:00",
    preferred_maintenance_window="sun:04:00-sun:05:00"
)
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting guide above
2. Review AWS EKS documentation
3. Check Kubernetes documentation
4. Open an issue in the repository

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

**Happy Deploying! 🚀**
