# Local Development with KinD and Skaffold

This guide explains how to develop and test the Todo application locally using KinD (Kubernetes in Docker) and Skaffold for rapid development cycles.

## Prerequisites

### Required Tools

Install the following tools on your macOS system:

```bash
# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install kind kubectl skaffold

# Verify installations
docker --version
kind --version
kubectl version --client
skaffold version
```

### Tool Versions (Recommended)
- Docker Desktop: 4.15+
- KinD: 0.17+
- kubectl: 1.25+
- Skaffold: 2.0+

## Quick Start

### 1. Setup Local Kubernetes Cluster

```bash
# Run the setup script
./scripts/setup-local-dev.sh
```

This script will:
- Create a KinD cluster named `todo-app-cluster`
- Install NGINX Ingress Controller
- Configure port forwarding (8080 → 80, 8443 → 443)

### 2. Start Development Mode

```bash
# Start Skaffold in development mode
skaffold dev
```

This will:
- Build Docker images for frontend and backend
- Deploy the application to KinD cluster
- Set up port forwarding
- Watch for code changes and auto-redeploy

### 3. Access the Application

- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:3000
- **Database**: localhost:5432 (postgres/password)

## Development Workflow

### Making Changes

1. **Backend Changes**: Edit files in `backend/`
   - Skaffold will rebuild the Docker image
   - Kubernetes will redeploy the backend pods
   - Changes are reflected automatically

2. **Frontend Changes**: Edit files in `frontend/`
   - Skaffold will rebuild the Docker image
   - Kubernetes will redeploy the frontend pods
   - Refresh browser to see changes

### Useful Commands

```bash
# View application logs
kubectl logs -f deployment/backend -n todo-app
kubectl logs -f deployment/frontend -n todo-app

# Check pod status
kubectl get pods -n todo-app

# Access database directly
kubectl port-forward svc/postgres-service 5432:5432 -n todo-app
# Then connect: psql -h localhost -U postgres -d tododb

# Restart a deployment
kubectl rollout restart deployment/backend -n todo-app

# Scale deployments
kubectl scale deployment backend --replicas=3 -n todo-app
```

## Project Structure

```
├── backend/                 # Node.js/Express API
│   ├── server.js           # Main server file
│   ├── package.json        # Dependencies
│   └── Dockerfile          # Backend container
├── frontend/               # HTML/CSS/JS Frontend
│   ├── index.html          # Main HTML file
│   ├── nginx.conf          # Nginx configuration
│   └── Dockerfile          # Frontend container
├── k8s-local/              # Local Kubernetes manifests
│   ├── namespace.yaml      # Application namespace
│   ├── postgres.yaml       # PostgreSQL database
│   ├── backend.yaml        # Backend deployment
│   ├── frontend.yaml       # Frontend deployment
│   └── ingress.yaml        # Ingress configuration
├── skaffold.yaml           # Skaffold configuration
├── kind-config.yaml        # KinD cluster configuration
└── scripts/                # Helper scripts
    ├── setup-local-dev.sh  # Setup script
    └── cleanup-local-dev.sh # Cleanup script
```

## Application Features

### Todo API Endpoints

The backend provides a full CRUD API for todos:

- `GET /health` - Health check
- `GET /api/todos` - Get all todos
- `GET /api/todos/:id` - Get specific todo
- `POST /api/todos` - Create new todo
- `PUT /api/todos/:id` - Update todo
- `DELETE /api/todos/:id` - Delete todo
- `PATCH /api/todos/:id/toggle` - Toggle completion status

### Frontend Features

- Modern responsive UI with Bootstrap
- Real-time backend status monitoring
- Full CRUD operations for todos
- Filter todos (All/Completed/Pending)
- Auto-refresh functionality

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

## Debugging and Troubleshooting

### Common Issues

#### 1. KinD Cluster Not Starting
```bash
# Check Docker is running
docker ps

# Delete and recreate cluster
kind delete cluster --name todo-app-cluster
./scripts/setup-local-dev.sh
```

#### 2. Images Not Building
```bash
# Check Skaffold configuration
skaffold config list

# Force rebuild
skaffold dev --force-rebuild
```

#### 3. Database Connection Issues
```bash
# Check PostgreSQL pod
kubectl get pods -n todo-app | grep postgres

# View PostgreSQL logs
kubectl logs deployment/postgres -n todo-app

# Test connection from backend pod
kubectl exec -it deployment/backend -n todo-app -- sh
# Inside pod: nc -zv postgres-service 5432
```

#### 4. Port Forwarding Issues
```bash
# Check what's using port 8080
lsof -i :8080

# Kill conflicting processes
kill -9 $(lsof -t -i:8080)

# Restart Skaffold
skaffold dev
```

### Viewing Logs

```bash
# All application logs
kubectl logs -f -l app=backend -n todo-app
kubectl logs -f -l app=frontend -n todo-app
kubectl logs -f -l app=postgres -n todo-app

# Skaffold logs
skaffold dev --verbosity=debug
```

### Database Management

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n todo-app -- psql -U postgres -d tododb

# Common SQL commands
\dt                    # List tables
SELECT * FROM todos;   # View all todos
\q                     # Quit
```

## Performance Testing

### Load Testing with curl

```bash
# Create multiple todos
for i in {1..10}; do
  curl -X POST http://localhost:3000/api/todos \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Test Todo $i\",\"description\":\"Generated todo $i\"}"
done

# Get all todos
curl http://localhost:3000/api/todos | jq .
```

### Monitoring Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n todo-app

# View resource limits
kubectl describe pod -l app=backend -n todo-app
```

## Advanced Configuration

### Custom Environment Variables

Edit `k8s-local/backend.yaml` to add environment variables:

```yaml
env:
- name: LOG_LEVEL
  value: "debug"
- name: MAX_CONNECTIONS
  value: "100"
```

### Persistent Storage

The PostgreSQL database uses a PersistentVolumeClaim for data persistence:

```bash
# Check PVC status
kubectl get pvc -n todo-app

# View storage usage
kubectl describe pvc postgres-pvc -n todo-app
```

### Scaling for Development

```bash
# Scale backend for load testing
kubectl scale deployment backend --replicas=3 -n todo-app

# Scale frontend
kubectl scale deployment frontend --replicas=2 -n todo-app
```

## Cleanup

### Stop Development

```bash
# Stop Skaffold (Ctrl+C in terminal)
# Or run cleanup script
./scripts/cleanup-local-dev.sh
```

### Complete Cleanup

```bash
# Remove everything including Docker images
./scripts/cleanup-local-dev.sh
# Answer 'y' when prompted to clean Docker images
```

## Tips and Best Practices

### Development Tips

1. **Use Skaffold Profiles**: Create different profiles for different environments
2. **Hot Reload**: Skaffold automatically rebuilds on file changes
3. **Debug Mode**: Use `skaffold debug` for debugging with breakpoints
4. **Resource Limits**: Set appropriate resource limits for local development

### Code Organization

1. **Separate Concerns**: Keep frontend and backend code separate
2. **Environment Variables**: Use env vars for configuration
3. **Error Handling**: Implement proper error handling in both frontend and backend
4. **Logging**: Use structured logging for better debugging

### Testing Strategy

1. **Unit Tests**: Add unit tests for backend API endpoints
2. **Integration Tests**: Test database interactions
3. **E2E Tests**: Test complete user workflows
4. **Load Tests**: Test application under load

## Next Steps

After local development, you can:

1. **Deploy to EKS**: Use the main CDK stack for AWS deployment
2. **CI/CD Pipeline**: Set up automated testing and deployment
3. **Monitoring**: Add Prometheus and Grafana for monitoring
4. **Security**: Implement authentication and authorization

## Troubleshooting Checklist

- [ ] Docker Desktop is running
- [ ] KinD cluster is created and running
- [ ] kubectl context is set to kind-todo-app-cluster
- [ ] All pods are in Running state
- [ ] Port forwarding is working (8080, 3000, 5432)
- [ ] Database is accessible and initialized
- [ ] Backend health check returns 200
- [ ] Frontend loads without errors

For additional help, check the logs and ensure all prerequisites are met.
