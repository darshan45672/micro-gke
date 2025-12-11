# Micro Frontend Kubernetes Deployment

This guide will help you deploy the Next.js and Vue.js micro frontends to your local Kubernetes cluster.

## Prerequisites

1. **Kubernetes Cluster** - One of the following:
   - Minikube
   - Docker Desktop with Kubernetes enabled
   - Kind (Kubernetes in Docker)
   - K3s

2. **kubectl** - Kubernetes command-line tool
3. **Container Runtime** - Podman or Docker

## Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Make the script executable
chmod +x build-and-deploy.sh

# Run the deployment script
./build-and-deploy.sh
```

This script will:
- Build both Docker images
- Load images into Kind or Minikube
- Deploy to Kubernetes
- Display access URLs

### Step 2: Set Up Port Forwarding (Required for Kind)

If you're using Kind, NodePort services are not directly accessible. You need to set up port forwarding:

```bash
# Make the script executable
chmod +x start-port-forward.sh

# Start port forwarding
./start-port-forward.sh
```

This will forward:
- `localhost:30001` → Next.js Landing Page
- `localhost:30002` → Vue.js Blog Listing

To stop port forwarding later:
```bash
./stop-port-forward.sh
```

### Option 2: Manual Deployment

#### Step 1: Build Docker Images

```bash
# Build Next.js app
cd mf1
podman build -t mf1-nextjs:latest .
cd ..

# Build Vue.js app
cd mf2
podman build -t mf2-vuejs:latest .
cd ..
```

#### Step 2: Load Images (Minikube Only)

If you're using Minikube, load the images:

```bash
minikube image load mf1-nextjs:latest
minikube image load mf2-vuejs:latest
```

#### Step 3: Deploy to Kubernetes

```bash
# Deploy Next.js micro frontend
kubectl apply -f k8s/mf1-deployment.yaml

# Deploy Vue.js micro frontend
kubectl apply -f k8s/mf2-deployment.yaml

# Optional: Deploy ingress
kubectl apply -f k8s/ingress.yaml
```

#### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services
kubectl get services

# Check deployments
kubectl get deployments
```

## Accessing the Applications

### Using NodePort (Default)

The services are exposed via NodePort:

- **Next.js Landing Page**: Port 30001
- **Vue.js Blog Listing**: Port 30002

**For Minikube:**
```bash
minikube ip  # Get your Minikube IP
# Access: http://<minikube-ip>:30001 (Next.js)
# Access: http://<minikube-ip>:30002 (Vue.js)
```

**For Docker Desktop or localhost clusters:**
```bash
# Access: http://localhost:30001 (Next.js)
# Access: http://localhost:30002 (Vue.js)
```

### Using Ingress (Optional)

If you deployed the ingress:

1. Install nginx ingress controller:
```bash
# For Minikube
minikube addons enable ingress

# For other clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

2. Add to `/etc/hosts`:
```
<cluster-ip>  mf.local
```

3. Access:
- Landing Page: http://mf.local
- Blog Listing: http://mf.local/blogs

## Important: Update Application URLs

After deployment, you need to update the hardcoded URLs in your applications:

### In Vue.js App (`mf2/src/App.vue`)

Update the `navigateToLanding` function:
```typescript
const navigateToLanding = () => {
  // Change from localhost:3000 to your NodePort URL
  window.location.href = 'http://<your-cluster-ip>:30001'
}
```

### In Next.js App (`mf1/app/page.tsx`)

Update the "View Blogs" button href:
```typescript
// Change from localhost:5173 to your NodePort URL
href="http://<your-cluster-ip>:30002"
```

## Scaling

```bash
# Scale Next.js deployment
kubectl scale deployment mf1-nextjs --replicas=3

# Scale Vue.js deployment
kubectl scale deployment mf2-vuejs --replicas=3
```

## Monitoring

```bash
# Watch pod status
kubectl get pods -w

# View logs
kubectl logs -f deployment/mf1-nextjs
kubectl logs -f deployment/mf2-vuejs

# Describe deployment
kubectl describe deployment mf1-nextjs
kubectl describe deployment mf2-vuejs
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f k8s/mf1-deployment.yaml
kubectl delete -f k8s/mf2-deployment.yaml
kubectl delete -f k8s/ingress.yaml

# Or delete by label
kubectl delete all -l tier=frontend
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>
```

### Images not found

If using Minikube:
```bash
# Verify images are loaded
minikube image ls | grep mf

# Reload images if needed
minikube image load mf1-nextjs:latest
minikube image load mf2-vuejs:latest
```

### Service not accessible

```bash
# Verify services
kubectl get svc

# Check endpoints
kubectl get endpoints

# For Minikube, use service URL
minikube service mf1-nextjs-service --url
minikube service mf2-vuejs-service --url
```

## Architecture

```
┌─────────────────────────────────────────────┐
│           Kubernetes Cluster                │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐ │
│  │  mf1-nextjs      │  │  mf2-vuejs      │ │
│  │  (Next.js)       │  │  (Vue.js)       │ │
│  │  Replicas: 2     │  │  Replicas: 2    │ │
│  │  Port: 3000      │  │  Port: 80       │ │
│  └────────┬─────────┘  └────────┬────────┘ │
│           │                     │          │
│  ┌────────▼─────────┐  ┌────────▼────────┐ │
│  │  Service         │  │  Service        │ │
│  │  NodePort: 30001 │  │  NodePort: 30002│ │
│  └──────────────────┘  └─────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

## Production Considerations

For production deployments, consider:

1. **Use proper domain names** instead of localhost
2. **Set up TLS/SSL** with cert-manager
3. **Configure resource limits** appropriately
4. **Add horizontal pod autoscaling** (HPA)
5. **Implement proper health checks**
6. **Use a proper image registry** (Docker Hub, GCR, ECR)
7. **Set up monitoring** with Prometheus/Grafana
8. **Configure proper networking** with service mesh (Istio, Linkerd)
9. **Implement CI/CD pipelines** for automated deployments
10. **Use ConfigMaps/Secrets** for configuration management
