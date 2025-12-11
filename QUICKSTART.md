# Quick Start Commands

## Prerequisites Check
```bash
# Check if gcloud is installed
gcloud --version

# Check if kubectl is installed
kubectl version --client

# Check if podman is installed
podman --version

# OR check if docker is installed
docker --version
```

## Step 1: Login to Google Cloud
```bash
gcloud auth login
```

## Step 2: Choose Your Project (Use Existing with Billing)
```bash
# List existing projects
gcloud projects list

# REQUIRED: Use an existing project with billing enabled
# Pick one from your list (e.g., test-24137, manthan-447604)
export PROJECT_ID="test-24137"  # Replace with your project
gcloud config set project $PROJECT_ID

# Verify billing is enabled
gcloud beta billing projects describe $PROJECT_ID
```

**⚠️ Important**: New projects require billing to be enabled. For this demo, **use an existing project** from your list.

## Step 3: Deploy Everything (Automated)
```bash
# Make scripts executable (first time only)
chmod +x deploy-to-gke.sh cleanup-gke.sh load-test.sh

# Run deployment
./deploy-to-gke.sh
```

## Step 4: Access Your Apps
```bash
# Get the IP address
kubectl get ingress micro-frontends-ingress

# Open in browser
# Next.js: http://YOUR_IP/mf1
# Vue.js:  http://YOUR_IP/mf2
```

## Step 5: Test Auto-Scaling
```bash
# In terminal 1: Generate load
./load-test.sh

# In terminal 2: Watch scaling
kubectl get hpa -w
```

## Useful Commands
```bash
# Check deployment status
kubectl get all

# View pods
kubectl get pods

# View logs
kubectl logs -f deployment/mf1-nextjs

# Scale manually
kubectl scale deployment mf1-nextjs --replicas=5

# Check HPA status
kubectl get hpa
```

## Cleanup (When Done)
```bash
./cleanup-gke.sh
```

---

**For detailed explanations, see [GKE-GUIDE.md](GKE-GUIDE.md)**
