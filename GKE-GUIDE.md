# Micro Frontends on Google Kubernetes Engine (GKE)

This project demonstrates deploying and scaling micro frontends (Next.js and Vue.js apps) on Google Kubernetes Engine with automatic scaling capabilities.

## 📋 Prerequisites

Before you begin, ensure you have:

1. **Google Cloud Account**: [Sign up for free](https://cloud.google.com/free)
2. **Google Cloud SDK (gcloud)**: [Installation Guide](https://cloud.google.com/sdk/docs/install)
3. **Podman or Docker**: For building container images
   - Podman (recommended): `brew install podman` (macOS) or see [podman.io](https://podman.io/getting-started/installation)
   - Docker: [Installation Guide](https://docs.docker.com/get-docker/)
4. **kubectl**: Install with `gcloud components install kubectl`

## 🏗️ Project Structure

```
micro-gke/
├── mf1/                          # Next.js micro frontend
│   ├── Dockerfile
│   └── ... (Next.js app files)
├── mf2/                          # Vue.js micro frontend
│   ├── Dockerfile
│   └── ... (Vue.js app files)
├── k8s/                          # Kubernetes manifests
│   ├── mf1-deployment.yaml       # Next.js deployment
│   ├── mf1-service.yaml          # Next.js service
│   ├── mf1-hpa.yaml             # Next.js autoscaling
│   ├── mf2-deployment.yaml       # Vue.js deployment
│   ├── mf2-service.yaml          # Vue.js service
│   ├── mf2-hpa.yaml             # Vue.js autoscaling
│   ├── ingress.yaml              # Load balancer config
│   └── managed-cert.yaml         # SSL certificate (optional)
├── deploy-to-gke.sh             # Automated deployment script
├── cleanup-gke.sh               # Cleanup script
└── load-test.sh                 # Load testing for auto-scaling demo
```

## 🚀 Quick Start (Automated Deployment)

### Step 1: Set up Google Cloud

```bash
# Login to Google Cloud
gcloud auth login

# List your existing projects with billing status
gcloud projects list

# IMPORTANT: Use an existing project with billing enabled
# Check billing at: https://console.cloud.google.com/billing
export PROJECT_ID="your-existing-project-id"  # e.g., "test-24137" or "manthan-447604"
gcloud config set project $PROJECT_ID

# Verify billing is enabled
gcloud beta billing projects describe $PROJECT_ID
```

**⚠️ Important**: Creating a new project requires enabling billing first. For a quick demo, **use an existing project** from your list that already has billing enabled (like `test-24137`, `manthan-447604`, etc.).

<details>
<summary>Optional: Create a new project (requires billing setup)</summary>

```bash
# Create a new project
gcloud projects create micro-gke-demo-$(date +%s) --name="Micro Frontends Demo"

# Link billing account (replace BILLING_ACCOUNT_ID)
# Get billing accounts: gcloud billing accounts list
gcloud billing projects link micro-gke-demo-XXXXX --billing-account=BILLING_ACCOUNT_ID

# Or enable billing via web console:
# https://console.cloud.google.com/billing
```
</details>
```

### Step 1.5: Set up Podman Authentication (Podman users only)

```bash
# Run the Podman authentication script
./setup-podman-gcr.sh

# Or manually authenticate:
gcloud auth configure-docker gcr.io
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io
```

### Step 2: Deploy Everything Automatically

```bash
# Make scripts executable
chmod +x deploy-to-gke.sh cleanup-gke.sh load-test.sh

# Run the deployment script
./deploy-to-gke.sh
```

The script will:
- ✅ Enable required GCP APIs
- ✅ Create a GKE cluster (3 nodes, auto-scaling 2-6 nodes)
- ✅ Build and push Docker images to Google Container Registry
- ✅ Deploy both micro frontends
- ✅ Set up auto-scaling (2-10 pods per app)
- ✅ Configure load balancer with path-based routing
- ✅ Display access URLs

**Expected time**: 10-15 minutes

## 📖 Manual Deployment (Step by Step)

If you prefer to understand each step:

### 1. Set up GCP Project

```bash
# Set your project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 2. Create GKE Cluster

```bash
gcloud container clusters create micro-frontends-cluster \
    --zone=us-central1-a \
    --num-nodes=3 \
    --machine-type=e2-medium \
    --enable-autoscaling \
    --min-nodes=2 \
    --max-nodes=6 \
    --enable-autorepair \
    --enable-autoupgrade
```

### 3. Get Cluster Credentials

```bash
gcloud container clusters get-credentials micro-frontends-cluster \
    --zone=us-central1-a
```

### 4. Authenticate with Container Registry

#### For Podman users:
```bash
# Authenticate Podman with GCR
gcloud auth configure-docker gcr.io
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io
```

#### For Docker users:
```bash
# Docker handles this automatically with gcloud
gcloud auth configure-docker
```

### 5. Build and Push Container Images

#### Using Podman:
```bash
cd mf1
podman build -t gcr.io/$PROJECT_ID/mf1-nextjs:latest .
podman push gcr.io/$PROJECT_ID/mf1-nextjs:latest
cd ..

cd mf2
podman build -t gcr.io/$PROJECT_ID/mf2-vue:latest .
podman push gcr.io/$PROJECT_ID/mf2-vue:latest
cd ..
```

#### OR using Docker:
```bash
cd mf1
docker build -t gcr.io/$PROJECT_ID/mf1-nextjs:latest .
docker push gcr.io/$PROJECT_ID/mf1-nextjs:latest
cd ..

cd mf2
docker build -t gcr.io/$PROJECT_ID/mf2-vue:latest .
docker push gcr.io/$PROJECT_ID/mf2-vue:latest
cd ..
```

### 6. Update Kubernetes Manifests

Replace `YOUR_PROJECT_ID` in the deployment files:

```bash
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/mf1-deployment.yaml
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/mf2-deployment.yaml
```

### 7. Deploy to Kubernetes

```bash
# Deploy applications
kubectl apply -f k8s/mf1-deployment.yaml
kubectl apply -f k8s/mf1-service.yaml
kubectl apply -f k8s/mf2-deployment.yaml
kubectl apply -f k8s/mf2-service.yaml

# Deploy auto-scaling
kubectl apply -f k8s/mf1-hpa.yaml
kubectl apply -f k8s/mf2-hpa.yaml

# Deploy ingress (load balancer)
kubectl apply -f k8s/ingress.yaml
```

### 8. Get Access URL

```bash
# Wait for Ingress IP (may take 5-10 minutes)
kubectl get ingress micro-frontends-ingress --watch

# Once you have an IP:
export INGRESS_IP=$(kubectl get ingress micro-frontends-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access your apps at: http://$INGRESS_IP"
```

## 🔍 Testing and Monitoring

### Check Deployment Status

```bash
# View all resources
kubectl get all

# Check pods
kubectl get pods

# Check services
kubectl get services

# Check HPA status
kubectl get hpa
```

### View Logs

```bash
# Next.js app logs
kubectl logs -f deployment/mf1-nextjs

# Vue.js app logs
kubectl logs -f deployment/mf2-vue
```

### Access Applications

```bash
# Get Ingress IP
export INGRESS_IP=$(kubectl get ingress micro-frontends-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access Next.js app
open http://$INGRESS_IP/mf1

# Access Vue.js app
open http://$INGRESS_IP/mf2
```

## 📊 Demonstrate Auto-Scaling

### Method 1: Using Load Test Script

```bash
./load-test.sh
```

In another terminal, watch the scaling:

```bash
kubectl get hpa -w
```

### Method 2: Manual Load Testing

```bash
# Install hey (load testing tool)
brew install hey  # macOS
# or download from: https://github.com/rakyll/hey

# Generate load
hey -z 2m -q 200 -c 50 http://$INGRESS_IP/mf1

# Watch auto-scaling in action
kubectl get hpa -w
kubectl get pods -w
```

### Method 3: Manual Scaling

```bash
# Scale up manually
kubectl scale deployment mf1-nextjs --replicas=5

# Scale down
kubectl scale deployment mf1-nextjs --replicas=2

# HPA will override manual scaling based on metrics
```

## 🎯 Key Features Demonstrated

1. **Container Orchestration**: Kubernetes manages multiple micro frontends
2. **Auto-Scaling**: Horizontal Pod Autoscaler scales based on CPU/Memory
3. **Load Balancing**: Ingress distributes traffic across pods
4. **Path-Based Routing**: Different apps at `/mf1` and `/mf2`
5. **Health Checks**: Liveness and readiness probes
6. **Resource Management**: CPU/Memory limits and requests
7. **Rolling Updates**: Zero-downtime deployments

## 📈 Scaling Configuration

### Current Settings:

**mf1-nextjs (Next.js)**:
- Min replicas: 2
- Max replicas: 10
- Scale up: When CPU > 70% or Memory > 80%
- Scale down: After 5 minutes of low usage

**mf2-vue (Vue.js)**:
- Min replicas: 2
- Max replicas: 8
- Scale up: When CPU > 70% or Memory > 80%
- Scale down: After 5 minutes of low usage

### Modify Scaling:

Edit `k8s/mf1-hpa.yaml` or `k8s/mf2-hpa.yaml` and apply:

```bash
kubectl apply -f k8s/mf1-hpa.yaml
```

## 🔄 Update Deployment

### Update Application Code:

```bash
# Make changes to your app
cd mf1
# ... edit files ...

# Rebuild and push (using Podman)
podman build -t gcr.io/$PROJECT_ID/mf1-nextjs:v2 .
podman push gcr.io/$PROJECT_ID/mf1-nextjs:v2

# OR using Docker
docker build -t gcr.io/$PROJECT_ID/mf1-nextjs:v2 .
docker push gcr.io/$PROJECT_ID/mf1-nextjs:v2

# Update deployment
kubectl set image deployment/mf1-nextjs mf1-nextjs=gcr.io/$PROJECT_ID/mf1-nextjs:v2

# Watch rollout
kubectl rollout status deployment/mf1-nextjs
```

### Rollback if Needed:

```bash
kubectl rollout undo deployment/mf1-nextjs
```

## 💰 Cost Management

**Estimated costs** (US Central region):
- 3 x e2-medium nodes: ~$75/month
- Load Balancer: ~$18/month
- Container Registry: Minimal for small images

**To minimize costs**:
- Delete cluster when not in use: `./cleanup-gke.sh`
- Use preemptible nodes (add `--preemptible` flag)
- Reduce node count during development

## 🧹 Cleanup

### Quick Cleanup:

```bash
./cleanup-gke.sh
```

### Manual Cleanup:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete cluster
gcloud container clusters delete micro-frontends-cluster --zone=us-central1-a

# Delete images
gcloud container images delete gcr.io/$PROJECT_ID/mf1-nextjs:latest
gcloud container images delete gcr.io/$PROJECT_ID/mf2-vue:latest
```

## 🐛 Troubleshooting

### Pods not starting:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Ingress not getting IP:

```bash
# Check ingress status
kubectl describe ingress micro-frontends-ingress

# Ensure HTTP Load Balancing is enabled
gcloud container clusters describe micro-frontends-cluster --zone=us-central1-a
```

### Images not pulling:

```bash
# Verify images exist
gcloud container images list --repository=gcr.io/$PROJECT_ID

# Check if cluster has permission
gcloud projects get-iam-policy $PROJECT_ID
```

### Podman authentication expired:

```bash
# Re-authenticate Podman with GCR (tokens expire after ~1 hour)
./setup-podman-gcr.sh

# Or manually:
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io
```

### Auto-scaling not working:

```bash
# Check metrics server
kubectl top nodes
kubectl top pods

# Check HPA status
kubectl describe hpa mf1-nextjs-hpa
```

## 📚 Learn More

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [GKE Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)

## 🎓 What You've Learned

After completing this demo, you understand:
- ✅ How to containerize web applications
- ✅ Creating and managing GKE clusters
- ✅ Kubernetes deployments and services
- ✅ Horizontal Pod Autoscaling
- ✅ Load balancing with Ingress
- ✅ Container registry management
- ✅ Monitoring and logging in K8s
- ✅ Cost-effective cloud resource management

## 📝 Next Steps

1. **Add HTTPS**: Configure SSL certificates
2. **CI/CD**: Set up automated deployments with GitHub Actions
3. **Monitoring**: Add Prometheus and Grafana
4. **Service Mesh**: Implement Istio for advanced traffic management
5. **Multi-region**: Deploy to multiple regions for high availability

---

**Need help?** Open an issue or check the troubleshooting section above.
