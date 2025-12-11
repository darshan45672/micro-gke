#!/bin/bash

# GKE Deployment Script for Micro Frontends
# This script automates the deployment of Next.js and Vue.js apps to Google Kubernetes Engine

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${PROJECT_ID:-""}
REGION=${REGION:-"us-central1"}
ZONE=${ZONE:-"us-central1-a"}
CLUSTER_NAME=${CLUSTER_NAME:-"micro-frontend-cluster"}
REPO_NAME=${REPO_NAME:-"micro-frontend-repo"}

echo -e "${BLUE}🚀 GKE Micro Frontend Deployment Script${NC}\n"

# Check if PROJECT_ID is set
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}PROJECT_ID not set. Please enter your Google Cloud Project ID:${NC}"
    read -p "Project ID: " PROJECT_ID
    export PROJECT_ID
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo "  Cluster: $CLUSTER_NAME"
echo "  Repository: $REPO_NAME"
echo ""

# Confirm before proceeding
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

echo -e "\n${BLUE}Step 1: Configuring gcloud${NC}"
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo -e "\n${BLUE}Step 2: Enabling required APIs${NC}"
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com

echo -e "\n${BLUE}Step 3: Checking for Artifact Registry repository${NC}"
if gcloud artifacts repositories describe $REPO_NAME --location=$REGION &>/dev/null; then
    echo -e "${GREEN}✅ Repository '$REPO_NAME' already exists${NC}"
else
    echo -e "${YELLOW}Creating Artifact Registry repository...${NC}"
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="Micro frontend container images"
    echo -e "${GREEN}✅ Repository created${NC}"
fi

echo -e "\n${BLUE}Step 4: Detecting container CLI${NC}"
# Detect container CLI (podman or docker)
if command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
    echo -e "${GREEN}✅ Using Podman${NC}"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
    echo -e "${GREEN}✅ Using Docker${NC}"
else
    echo -e "${RED}❌ Error: Neither podman nor docker found${NC}"
    exit 1
fi

echo -e "\n${BLUE}Step 5: Configuring authentication${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev

echo -e "\n${BLUE}Step 6: Building container images for AMD64 (GKE architecture)${NC}"
echo -e "${YELLOW}⚠️  Building for linux/amd64 platform (GKE requires AMD64)${NC}"
echo -e "${BLUE}Building mf1 (Next.js)...${NC}"
$CONTAINER_CLI build --platform linux/amd64 -t mf1-nextjs:latest mf1/
echo -e "${GREEN}✅ mf1 built${NC}"

echo -e "${BLUE}Building mf2 (Vue.js)...${NC}"
$CONTAINER_CLI build --platform linux/amd64 -t mf2-vuejs:latest mf2/
echo -e "${GREEN}✅ mf2 built${NC}"

echo -e "\n${BLUE}Step 7: Tagging images for Artifact Registry${NC}"
$CONTAINER_CLI tag mf1-nextjs:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
$CONTAINER_CLI tag mf2-vuejs:latest ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
echo -e "${GREEN}✅ Images tagged${NC}"

echo -e "\n${BLUE}Step 8: Pushing images to Artifact Registry${NC}"
$CONTAINER_CLI push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
$CONTAINER_CLI push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
echo -e "${GREEN}✅ Images pushed${NC}"

echo -e "\n${BLUE}Step 9: Checking for GKE cluster${NC}"
if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
    echo -e "${GREEN}✅ Cluster '$CLUSTER_NAME' exists${NC}"
    echo -e "${BLUE}Getting cluster credentials...${NC}"
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
else
    echo -e "${YELLOW}Cluster not found. Creating GKE cluster...${NC}"
    echo -e "${YELLOW}⚠️  This will take 3-5 minutes${NC}"
    gcloud container clusters create $CLUSTER_NAME \
        --zone=$ZONE \
        --num-nodes=2 \
        --machine-type=e2-medium \
        --enable-autoscaling \
        --min-nodes=2 \
        --max-nodes=4 \
        --disk-size=20GB
    
    echo -e "${GREEN}✅ Cluster created${NC}"
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
fi

echo -e "\n${BLUE}Step 10: Creating Kubernetes deployment manifests${NC}"

# Create temporary deployment files with correct image paths
cat > /tmp/gke-mf1-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf1-nextjs
  labels:
    app: mf1-nextjs
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
        image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf1-nextjs:latest
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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
EOF

cat > /tmp/gke-mf2-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mf2-vuejs
  labels:
    app: mf2-vuejs
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
        image: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/mf2-vuejs:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "250m"
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
EOF

echo -e "${GREEN}✅ Manifests created${NC}"

echo -e "\n${BLUE}Step 11: Deploying to GKE${NC}"
kubectl apply -f /tmp/gke-mf1-deployment.yaml
kubectl apply -f /tmp/gke-mf2-deployment.yaml

echo -e "\n${BLUE}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/mf1-nextjs
kubectl wait --for=condition=available --timeout=300s deployment/mf2-vuejs

echo -e "${GREEN}✅ Deployments are ready${NC}"

echo -e "\n${BLUE}Step 12: Waiting for LoadBalancer IPs (this may take 2-5 minutes)...${NC}"

# Wait for LoadBalancer IPs
echo -e "${YELLOW}Waiting for mf1-nextjs-service external IP...${NC}"
while [ -z "$MF1_IP" ]; do
    MF1_IP=$(kubectl get service mf1-nextjs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [ -z "$MF1_IP" ] && echo -n "." && sleep 5
done
echo -e "\n${GREEN}✅ mf1-nextjs-service: $MF1_IP${NC}"

echo -e "${YELLOW}Waiting for mf2-vuejs-service external IP...${NC}"
while [ -z "$MF2_IP" ]; do
    MF2_IP=$(kubectl get service mf2-vuejs-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [ -z "$MF2_IP" ] && echo -n "." && sleep 5
done
echo -e "\n${GREEN}✅ mf2-vuejs-service: $MF2_IP${NC}"

echo -e "\n${GREEN}🎉 Deployment Complete!${NC}\n"

echo -e "${BLUE}📋 Deployment Information:${NC}"
echo "  Cluster: $CLUSTER_NAME"
echo "  Zone: $ZONE"
echo "  Project: $PROJECT_ID"
echo ""

echo -e "${BLUE}🌐 Access Your Applications:${NC}"
echo "  Next.js Landing Page: ${GREEN}http://${MF1_IP}${NC}"
echo "  Vue.js Blog Listing:  ${GREEN}http://${MF2_IP}${NC}"
echo ""

echo -e "${YELLOW}⚠️  Note: URLs are currently hardcoded to localhost:30001 and localhost:30002${NC}"
echo -e "${YELLOW}To update URLs and redeploy with correct LoadBalancer IPs:${NC}"
echo ""
echo -e "${BLUE}1. Update environment files:${NC}"
echo "   echo \"NEXT_PUBLIC_BLOG_URL=http://${MF2_IP}\" > mf1/.env.production"
echo "   echo \"VITE_LANDING_URL=http://${MF1_IP}\" > mf2/.env.production"
echo ""
echo -e "${BLUE}2. Run this script again to rebuild and redeploy${NC}"
echo ""

echo -e "${BLUE}📊 Useful Commands:${NC}"
echo "  View pods:     kubectl get pods"
echo "  View services: kubectl get services"
echo "  View logs:     kubectl logs -l app=mf1-nextjs"
echo "  Scale app:     kubectl scale deployment mf1-nextjs --replicas=3"
echo ""

echo -e "${BLUE}🧹 Cleanup:${NC}"
echo "  Delete apps:   kubectl delete -f /tmp/gke-mf1-deployment.yaml -f /tmp/gke-mf2-deployment.yaml"
echo "  Delete cluster: gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE"
echo ""

# Save the deployment info
cat > deployment-info.txt <<EOF
GKE Deployment Information
==========================

Cluster: $CLUSTER_NAME
Zone: $ZONE
Region: $REGION
Project: $PROJECT_ID
Repository: $REPO_NAME

Application URLs:
- Next.js: http://${MF1_IP}
- Vue.js: http://${MF2_IP}

Deployed: $(date)
EOF

echo -e "${GREEN}✅ Deployment info saved to deployment-info.txt${NC}"
