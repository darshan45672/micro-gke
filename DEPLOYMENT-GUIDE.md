# Micro Frontend Deployment Guide

Complete step-by-step guide for deploying Next.js and Vue.js micro frontends to Google Kubernetes Engine (GKE).

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Local Kubernetes Deployment (Kind)](#local-kubernetes-deployment-kind)
- [GKE Production Deployment](#gke-production-deployment)
- [Architecture Considerations](#architecture-considerations)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Cleanup](#cleanup)

---

## 🏗️ Architecture Overview

This project demonstrates a micro frontend architecture with:

- **MF1 (Next.js)**: Landing page with "View Blogs" button
- **MF2 (Vue.js)**: Blog listing page with PrimeVue components

### Technology Stack

- **Frontend Frameworks**: Next.js 16.0.8, Vue.js 3.5.25
- **UI Library**: PrimeVue 4.5.3
- **Container Runtime**: Docker/Podman
- **Orchestration**: Kubernetes (Kind for local, GKE for production)
- **Cloud Platform**: Google Cloud Platform (GCP)

---

## ✅ Prerequisites

### Required Tools

1. **Node.js** (v20+)
   ```bash
   node --version
   ```

2. **Container Runtime** (Docker or Podman)
   ```bash
   docker --version
   # OR
   podman --version
   ```

3. **kubectl** (Kubernetes CLI)
   ```bash
   kubectl version --client
   ```

4. **Kind** (for local Kubernetes)
   ```bash
   kind version
   ```

5. **Google Cloud SDK** (for GKE deployment)
   ```bash
   gcloud --version
   ```

### GCP Requirements

- Active GCP account with billing enabled
- Project with sufficient permissions
- APIs to enable:
  - Kubernetes Engine API
  - Artifact Registry API
  - Compute Engine API

---

## 💻 Local Development Setup

### Step 1: Clone and Install Dependencies

```bash
# Navigate to project directory
cd micro-gke

# Install Next.js app dependencies
cd mf1
npm install
cd ..

# Install Vue.js app dependencies
cd mf2
npm install
cd ..
```

### Step 2: Configure Environment Variables

Create environment files for local development:

**mf1/.env.local**
```env
NEXT_PUBLIC_BLOG_URL=http://localhost:8081
```

**mf2/.env.local**
```env
VITE_LANDING_URL=http://localhost:3000
```

### Step 3: Run in Development Mode

**Terminal 1 - Next.js App:**
```bash
cd mf1
npm run dev
# Runs on http://localhost:3000
```

**Terminal 2 - Vue.js App:**
```bash
cd mf2
npm run dev
# Runs on http://localhost:5173
```

### Step 4: Build for Production

```bash
# Build Next.js app
cd mf1
npm run build

# Build Vue.js app
cd mf2
npm run build
```

---

## 🐳 Local Kubernetes Deployment (Kind)

### Step 1: Create Kind Cluster

```bash
# Create cluster with port mappings
kind create cluster --name micro-gke --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
  - containerPort: 30002
    hostPort: 30002
    protocol: TCP
EOF
```

### Step 2: Configure Environment for Local Deployment

**mf1/.env.production**
```env
NEXT_PUBLIC_BLOG_URL=http://localhost:30002
```

**mf2/.env.production**
```env
VITE_LANDING_URL=http://localhost:30001
```

### Step 3: Build Container Images

```bash
# Build Next.js image
docker build -t mf1-nextjs:latest mf1/
# OR with Podman
podman build -t mf1-nextjs:latest mf1/

# Build Vue.js image
docker build -t mf2-vuejs:latest mf2/
# OR with Podman
podman build -t mf2-vuejs:latest mf2/
```

### Step 4: Load Images into Kind

```bash
# Load images into Kind cluster
kind load docker-image mf1-nextjs:latest --name micro-gke
kind load docker-image mf2-vuejs:latest --name micro-gke
```

### Step 5: Deploy to Kind

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/mf1-deployment.yaml
kubectl apply -f k8s/mf2-deployment.yaml

# Verify deployments
kubectl get pods
kubectl get svc
```

### Step 6: Access Applications

**⚠️ Important**: Kind requires port forwarding for NodePort services.

**Option A - Automated (Recommended):**
```bash
# Start port forwarding
./start-port-forward.sh

# Stop port forwarding
./stop-port-forward.sh
```

**Option B - Manual:**
```bash
# Terminal 1 - MF1 port forward
kubectl port-forward svc/mf1-nextjs-service 30001:80

# Terminal 2 - MF2 port forward
kubectl port-forward svc/mf2-vuejs-service 30002:80
```

**Access URLs:**
- Next.js Landing Page: http://localhost:30001
- Vue.js Blog Listing: http://localhost:30002

---

## ☁️ GKE Production Deployment

### Architecture Differences: Kind vs GKE

| Aspect | Kind (Local) | GKE (Production) |
|--------|-------------|------------------|
| Service Type | NodePort | LoadBalancer |
| Access | Port forwarding required | Public IP addresses |
| Image Registry | Local images | Google Artifact Registry |
| Image Architecture | Host architecture (ARM64/AMD64) | AMD64 (x86_64) |
| Scalability | Single node | Multi-node with autoscaling |
| Cost | Free | ~$105/month |

### Step 1: GCP Project Setup

```bash
# Login to GCP
gcloud auth login

# List available projects
gcloud projects list

# Set your project (replace with your project ID)
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Verify billing is enabled
gcloud billing projects describe $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

### Step 2: Create Artifact Registry

```bash
# Set variables
export REGION="us-central1"
export REPO_NAME="micro-frontend-repo"

# Create repository
gcloud artifacts repositories create $REPO_NAME \
  --repository-format=docker \
  --location=$REGION \
  --description="Micro frontend container images"

# Configure Docker/Podman authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

### Step 3: Build Images for AMD64 Architecture

**⚠️ Critical**: GKE nodes run AMD64 architecture. If building on Apple Silicon (ARM64), use `--platform` flag:

```bash
# Detect container CLI
if command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
fi

# Build for AMD64 (required for GKE)
$CONTAINER_CLI build --platform linux/amd64 -t mf1-nextjs:latest mf1/
$CONTAINER_CLI build --platform linux/amd64 -t mf2-vuejs:latest mf2/
```

**Why `--platform linux/amd64`?**
- GKE nodes use AMD64/x86_64 processors
- Apple Silicon Macs build ARM64 images by default
- Cross-platform build prevents "exec format error"
- Build time increases (no cache reuse from ARM64 builds)

### Step 4: Tag and Push Images

```bash
# Tag images for Artifact Registry
$CONTAINER_CLI tag mf1-nextjs:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest

$CONTAINER_CLI tag mf2-vuejs:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest

# Push to Artifact Registry
$CONTAINER_CLI push \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest

$CONTAINER_CLI push \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest

# Verify images
gcloud artifacts docker images list \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}
```

### Step 5: Create GKE Cluster

```bash
# Set cluster configuration
export CLUSTER_NAME="micro-frontend-cluster"
export ZONE="${REGION}-a"

# Create cluster
gcloud container clusters create $CLUSTER_NAME \
  --zone=$ZONE \
  --num-nodes=2 \
  --machine-type=e2-medium \
  --disk-size=20GB \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=4 \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

**Cluster Specifications:**
- **Nodes**: 2 (autoscales to 4)
- **Machine Type**: e2-medium (2 vCPU, 4GB RAM)
- **Disk**: 20GB per node
- **Features**: Auto-repair, auto-upgrade enabled

### Step 6: Create GKE Deployment Manifests

**GKE deployment files differ from Kind deployments:**
- Service type: LoadBalancer (not NodePort)
- Image paths: Point to Artifact Registry
- Resource limits: Production-appropriate values

Create `/tmp/gke-mf1-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf1-nextjs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mf1-nextjs
  template:
    metadata:
      labels:
        app: mf1-nextjs
    spec:
      containers:
      - name: mf1-nextjs
        image: us-central1-docker.pkg.dev/YOUR_PROJECT_ID/micro-frontend-repo/mf1-nextjs:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mf1-nextjs-service
spec:
  type: LoadBalancer
  selector:
    app: mf1-nextjs
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
```

Create `/tmp/gke-mf2-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf2-vuejs
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mf2-vuejs
  template:
    metadata:
      labels:
        app: mf2-vuejs
    spec:
      containers:
      - name: mf2-vuejs
        image: us-central1-docker.pkg.dev/YOUR_PROJECT_ID/micro-frontend-repo/mf2-vuejs:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: mf2-vuejs-service
spec:
  type: LoadBalancer
  selector:
    app: mf2-vuejs
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

### Step 7: Deploy to GKE

```bash
# Apply deployments
kubectl apply -f /tmp/gke-mf1-deployment.yaml
kubectl apply -f /tmp/gke-mf2-deployment.yaml

# Monitor deployment
kubectl get deployments -w

# Check pod status
kubectl get pods

# View events
kubectl get events --sort-by='.lastTimestamp'
```

**Expected Output:**
```
NAME         READY   STATUS    RESTARTS   AGE
mf1-nextjs   2/2     Running   0          1m
mf2-vuejs    2/2     Running   0          1m
```

### Step 8: Get LoadBalancer IPs

```bash
# Check services
kubectl get svc

# Wait for external IPs (takes 2-5 minutes)
kubectl get svc -w

# Get specific IPs
export MF1_IP=$(kubectl get svc mf1-nextjs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MF2_IP=$(kubectl get svc mf2-vuejs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Next.js App: http://$MF1_IP"
echo "Vue.js App: http://$MF2_IP"
```

### Step 9: Update Environment Variables (Optional)

To enable cross-navigation between apps:

**Update mf1/.env.production:**
```env
NEXT_PUBLIC_BLOG_URL=http://YOUR_MF2_LOADBALANCER_IP
```

**Update mf2/.env.production:**
```env
VITE_LANDING_URL=http://YOUR_MF1_LOADBALANCER_IP
```

**Rebuild and redeploy:**
```bash
# Rebuild with new URLs
$CONTAINER_CLI build --platform linux/amd64 -t mf1-nextjs:latest mf1/
$CONTAINER_CLI build --platform linux/amd64 -t mf2-vuejs:latest mf2/

# Tag and push
$CONTAINER_CLI tag mf1-nextjs:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
$CONTAINER_CLI push \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest

$CONTAINER_CLI tag mf2-vuejs:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
$CONTAINER_CLI push \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest

# Restart deployments
kubectl rollout restart deployment/mf1-nextjs
kubectl rollout restart deployment/mf2-vuejs
```

### Step 10: Automated Deployment (Recommended)

Use the provided script for automated deployment:

```bash
# Make script executable
chmod +x deploy-to-gke.sh

# Run deployment
PROJECT_ID="your-project-id" ./deploy-to-gke.sh
```

The script automatically:
- ✅ Enables required GCP APIs
- ✅ Creates Artifact Registry repository
- ✅ Detects container CLI (Docker/Podman)
- ✅ Builds images for AMD64 architecture
- ✅ Pushes to Artifact Registry
- ✅ Creates or uses existing GKE cluster
- ✅ Generates deployment manifests
- ✅ Deploys applications
- ✅ Retrieves LoadBalancer IPs

---

## 🏛️ Architecture Considerations

### Container Image Architecture

**Problem**: Apple Silicon Macs build ARM64 images, but GKE runs AMD64 nodes.

**Solution**: Use `--platform linux/amd64` flag during build.

**Error Without Flag**:
```
exec /usr/local/bin/docker-entrypoint.sh: exec format error
```

**Build Commands Comparison**:
```bash
# ❌ Wrong - builds for host architecture (ARM64 on Mac)
podman build -t app:latest .

# ✅ Correct - builds for GKE architecture (AMD64)
podman build --platform linux/amd64 -t app:latest .
```

### Service Types

| Feature | NodePort | LoadBalancer |
|---------|----------|--------------|
| Use Case | Local development | Production |
| External Access | Requires port forwarding | Automatic public IP |
| Port Range | 30000-32767 | Standard (80, 443) |
| Load Balancing | Manual | Automatic |
| Cost | Free | ~$18/month each |
| Cloud Provider | Any Kubernetes | GKE, EKS, AKS |

### Resource Allocation

**Development (Kind)**:
- No resource limits needed
- Single node sufficient
- Minimal overhead

**Production (GKE)**:
```yaml
resources:
  requests:
    cpu: "100m"      # Minimum guaranteed
    memory: "128Mi"
  limits:
    cpu: "500m"      # Maximum allowed
    memory: "512Mi"
```

### Health Checks

**Liveness Probe**: Restarts unhealthy containers
```yaml
livenessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Readiness Probe**: Controls traffic routing
```yaml
readinessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## 🔧 Troubleshooting

### Pod Status Issues

**Check pod status:**
```bash
kubectl get pods
```

**Common statuses and solutions:**

1. **CrashLoopBackOff**
   ```bash
   # Check logs
   kubectl logs -l app=mf1-nextjs --tail=50
   
   # Check events
   kubectl get events --sort-by='.lastTimestamp'
   ```

2. **ImagePullBackOff**
   ```bash
   # Verify image exists
   gcloud artifacts docker images list \
     ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}
   
   # Check authentication
   gcloud auth configure-docker ${REGION}-docker.pkg.dev
   ```

3. **Exec Format Error**
   ```bash
   # Cause: Wrong architecture (ARM64 vs AMD64)
   # Solution: Rebuild with --platform linux/amd64
   podman build --platform linux/amd64 -t app:latest .
   ```

### LoadBalancer Pending

**Check service status:**
```bash
kubectl describe svc mf1-nextjs-service
```

**Common causes:**
- Insufficient GCP quotas
- Regional capacity issues
- Firewall rules blocking

**Wait longer (5-10 minutes) or check:**
```bash
gcloud compute forwarding-rules list
```

### Port Forwarding Not Working (Kind)

**Verify Kind cluster configuration:**
```bash
# Check if ports are mapped
docker ps | grep micro-gke

# Restart port forwarding
./stop-port-forward.sh
./start-port-forward.sh
```

### Build Failures

**Docker/Podman not found:**
```bash
# Install Docker Desktop (Mac)
# OR install Podman
brew install podman
podman machine init
podman machine start
```

**Build platform error:**
```bash
# If using Docker and --platform fails
docker buildx create --use
docker buildx build --platform linux/amd64 -t app:latest .
```

### GKE Cluster Issues

**Authentication error:**
```bash
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

**Quota exceeded:**
```bash
# Check quotas
gcloud compute project-info describe --project=$PROJECT_ID

# Request quota increase in GCP Console
```

### Monitoring Commands

```bash
# Watch all pods
kubectl get pods -w

# Stream logs
kubectl logs -f deployment/mf1-nextjs

# Describe pod for detailed info
kubectl describe pod <pod-name>

# Check resource usage
kubectl top pods
kubectl top nodes

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

---

## 💰 Cost Optimization

### Monthly Cost Breakdown (GKE)

| Resource | Configuration | Cost/Month |
|----------|--------------|------------|
| GKE Cluster Management | Standard | $0 (free tier) |
| Compute Nodes | 2x e2-medium | ~$70 |
| LoadBalancers | 2x external | ~$36 |
| Artifact Registry | Storage + egress | ~$1-5 |
| **Total** | | **~$105** |

### Cost Saving Strategies

1. **Use Autopilot GKE** (Pay per pod, not per node)
   ```bash
   gcloud container clusters create-auto $CLUSTER_NAME \
     --region=$REGION
   ```

2. **Scale Down During Off-Hours**
   ```bash
   # Scale to 0 replicas
   kubectl scale deployment/mf1-nextjs --replicas=0
   kubectl scale deployment/mf2-vuejs --replicas=0
   
   # Scale back up
   kubectl scale deployment/mf1-nextjs --replicas=2
   kubectl scale deployment/mf2-vuejs --replicas=2
   ```

3. **Use Preemptible Nodes** (80% cheaper, may be terminated)
   ```bash
   gcloud container node-pools create preemptible-pool \
     --cluster=$CLUSTER_NAME \
     --zone=$ZONE \
     --preemptible \
     --num-nodes=2
   ```

4. **Use Internal Load Balancing** (If public access not needed)
   ```yaml
   metadata:
     annotations:
       cloud.google.com/load-balancer-type: "Internal"
   ```

5. **Combine Services Behind One LoadBalancer** (Ingress)
   ```bash
   # Use single Ingress with path-based routing
   # Saves ~$18/month (one LoadBalancer instead of two)
   ```

6. **Delete Cluster When Not in Use**
   ```bash
   gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE
   ```

### Free Tier Options (Development)

**For non-production use:**
- Use Kind (free, local)
- Use GKE Autopilot free tier ($74.40/month credit)
- Use Cloud Run (serverless, pay per request)
- Use e2-micro instances (always free tier eligible)

---

## 🧹 Cleanup

### Delete Local Kind Cluster

```bash
# Stop port forwarding
./stop-port-forward.sh

# Delete cluster
kind delete cluster --name micro-gke

# Verify deletion
kind get clusters
```

### Delete GKE Resources

**Option 1 - Delete Entire Cluster** (Recommended for demo)
```bash
# Delete cluster (removes all resources)
gcloud container clusters delete $CLUSTER_NAME \
  --zone=$ZONE \
  --quiet

# Delete LoadBalancers are automatically removed with cluster
```

**Option 2 - Delete Applications Only** (Keep cluster)
```bash
# Delete deployments and services
kubectl delete -f /tmp/gke-mf1-deployment.yaml
kubectl delete -f /tmp/gke-mf2-deployment.yaml

# Or delete by resource type
kubectl delete deployment mf1-nextjs mf2-vuejs
kubectl delete service mf1-nextjs-service mf2-vuejs-service
```

**Delete Artifact Registry**
```bash
# Delete repository
gcloud artifacts repositories delete $REPO_NAME \
  --location=$REGION \
  --quiet

# Or delete specific images
gcloud artifacts docker images delete \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest \
  --delete-tags \
  --quiet
```

**Delete Project** (⚠️ Nuclear option)
```bash
# Deletes everything in the project
gcloud projects delete $PROJECT_ID
```

### Verify Cleanup

```bash
# Check clusters
gcloud container clusters list

# Check artifact registry
gcloud artifacts repositories list

# Check compute resources
gcloud compute forwarding-rules list
gcloud compute addresses list
```

---

## 📚 Additional Resources

### Documentation

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Vue.js Production Deployment](https://vuejs.org/guide/best-practices/production-deployment.html)

### Useful Commands Reference

```bash
# Kubernetes basics
kubectl get all
kubectl describe <resource> <name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/sh

# GKE specific
gcloud container clusters list
gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE
gcloud container node-pools list --cluster=$CLUSTER_NAME --zone=$ZONE

# Container images
docker images
podman images
docker system prune -a

# Port forwarding
kubectl port-forward svc/<service-name> <local-port>:<service-port>
kubectl port-forward pod/<pod-name> <local-port>:<container-port>
```

---

## 🎯 Next Steps

### For Production

1. **Set up Custom Domain**
   - Register domain name
   - Configure Cloud DNS
   - Create DNS A records pointing to LoadBalancer IPs

2. **Enable HTTPS**
   - Install cert-manager
   - Configure Let's Encrypt
   - Use GKE managed certificates

3. **Implement CI/CD**
   - Set up Cloud Build triggers
   - Automate image builds on git push
   - Deploy to GKE automatically

4. **Add Monitoring**
   - Enable GKE monitoring and logging
   - Set up Cloud Monitoring dashboards
   - Configure alerting policies

5. **Improve Security**
   - Enable Workload Identity
   - Use private GKE cluster
   - Implement network policies
   - Scan images for vulnerabilities

6. **Optimize Performance**
   - Enable Cloud CDN
   - Use Cloud Armor for DDoS protection
   - Implement caching strategies
   - Configure horizontal pod autoscaling

### Project Extensions

- Add authentication (OAuth, JWT)
- Implement API gateway
- Add database (Cloud SQL, Firestore)
- Create admin dashboard
- Add more micro frontends
- Implement module federation

---

## 📝 Summary

This guide covered:

✅ Local development setup  
✅ Containerization with Docker/Podman  
✅ Local Kubernetes deployment with Kind  
✅ Production deployment to GKE  
✅ Architecture considerations (ARM64 vs AMD64)  
✅ LoadBalancer vs NodePort services  
✅ Troubleshooting common issues  
✅ Cost optimization strategies  
✅ Complete cleanup procedures  

**Key Learnings:**
- Kind requires port forwarding for NodePort services
- GKE uses LoadBalancer for automatic public IPs
- ARM64 images won't run on AMD64 GKE nodes
- Use `--platform linux/amd64` when building on Apple Silicon
- Artifact Registry requires authentication configuration
- LoadBalancers take 2-5 minutes to provision external IPs

---

**Deployment Date**: December 11, 2025  
**Project**: Micro Frontend Demo (Next.js + Vue.js)  
**Repository**: [micro-gke](https://github.com/darshan45672/micro-gke)
