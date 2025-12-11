#!/bin/bash

# Micro Frontends GKE Deployment Script
# This script automates the deployment of micro frontends to Google Kubernetes Engine

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Micro Frontends GKE Deployment ===${NC}\n"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    echo "Install it with: gcloud components install kubectl"
    exit 1
fi

# Show available projects
echo -e "${YELLOW}Available GCP Projects:${NC}"
gcloud projects list --format="table(projectId,name,projectNumber)"

echo -e "\n${YELLOW}Note: The project must have billing enabled.${NC}"
echo -e "${YELLOW}Check billing status: https://console.cloud.google.com/billing${NC}\n"

# Prompt for project ID
read -p "Enter your GCP Project ID: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

# Set the project
echo -e "\n${YELLOW}Setting GCP project...${NC}"
gcloud config set project $PROJECT_ID

# Check if billing is enabled (with timeout)
echo -e "\n${YELLOW}Checking billing status...${NC}"

# Try to enable APIs first - this will fail if billing is not enabled
if ! gcloud services enable container.googleapis.com compute.googleapis.com containerregistry.googleapis.com --quiet 2>/dev/null; then
    echo -e "${RED}Error: Cannot enable APIs. Billing is likely not enabled for this project!${NC}"
    echo -e "${YELLOW}Please enable billing at: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID${NC}"
    echo -e "\nAlternatively, use an existing project with billing enabled from the list above."
    exit 1
fi

echo -e "${GREEN}✓ Billing is enabled and APIs are being activated${NC}"

# Prompt for cluster details
read -p "Enter cluster name (default: micro-frontends-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-micro-frontends-cluster}

read -p "Enter region (default: us-central1): " REGION
REGION=${REGION:-us-central1}

read -p "Enter zone (default: us-central1-a): " ZONE
ZONE=${ZONE:-us-central1-a}

# APIs already enabled in billing check above
echo -e "\n${YELLOW}Verifying GCP APIs are enabled...${NC}"
sleep 2  # Give APIs a moment to activate

# Create GKE cluster
echo -e "\n${YELLOW}Creating GKE cluster...${NC}"
echo "This may take 5-10 minutes..."
gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=2 \
    --machine-type=e2-small \
    --disk-size=30 \
    --disk-type=pd-standard \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=4 \
    --enable-autorepair \
    --enable-autoupgrade \
    --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver

# Get cluster credentials
echo -e "\n${YELLOW}Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Authenticate Podman with GCR
echo -e "\n${YELLOW}Authenticating Podman with Google Container Registry...${NC}"
gcloud auth configure-docker gcr.io --quiet
ACCESS_TOKEN=$(gcloud auth print-access-token)
echo $ACCESS_TOKEN | podman login -u oauth2accesstoken --password-stdin gcr.io

# Build and push container images using Podman
echo -e "\n${YELLOW}Building and pushing container images...${NC}"

echo -e "${YELLOW}Building mf1-nextjs...${NC}"
cd mf1
podman build --platform=linux/amd64 -t gcr.io/$PROJECT_ID/mf1-nextjs:latest .
podman push gcr.io/$PROJECT_ID/mf1-nextjs:latest
cd ..

echo -e "${YELLOW}Building mf2-vue...${NC}"
cd mf2
podman build --platform=linux/amd64 -t gcr.io/$PROJECT_ID/mf2-vue:latest .
podman push gcr.io/$PROJECT_ID/mf2-vue:latest
cd ..

# Update Kubernetes manifests with project ID
echo -e "\n${YELLOW}Updating Kubernetes manifests...${NC}"
sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/mf1-deployment.yaml
sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" k8s/mf2-deployment.yaml

# Deploy to Kubernetes
echo -e "\n${YELLOW}Deploying to Kubernetes...${NC}"
kubectl apply -f k8s/mf1-deployment.yaml
kubectl apply -f k8s/mf1-service.yaml
kubectl apply -f k8s/mf2-deployment.yaml
kubectl apply -f k8s/mf2-service.yaml

# Deploy HPA
echo -e "\n${YELLOW}Setting up Horizontal Pod Autoscaling...${NC}"
kubectl apply -f k8s/mf1-hpa.yaml
kubectl apply -f k8s/mf2-hpa.yaml

# Deploy Ingress
echo -e "\n${YELLOW}Deploying Ingress...${NC}"
kubectl apply -f k8s/ingress.yaml

# Wait for deployments
echo -e "\n${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/mf1-nextjs
kubectl wait --for=condition=available --timeout=300s deployment/mf2-vue

# Get Ingress IP
echo -e "\n${YELLOW}Waiting for Ingress IP address...${NC}"
echo "This may take a few minutes..."
sleep 30

INGRESS_IP=$(kubectl get ingress micro-frontends-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}\n"
echo -e "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "Region: ${GREEN}$REGION${NC}"
echo -e "Zone: ${GREEN}$ZONE${NC}"
echo -e "\nAccess your applications at:"
echo -e "  Next.js App (mf1): ${GREEN}http://$INGRESS_IP/mf1${NC}"
echo -e "  Vue.js App (mf2):  ${GREEN}http://$INGRESS_IP/mf2${NC}"
echo -e "\nUseful commands:"
echo -e "  View pods:        ${YELLOW}kubectl get pods${NC}"
echo -e "  View services:    ${YELLOW}kubectl get services${NC}"
echo -e "  View HPA status:  ${YELLOW}kubectl get hpa${NC}"
echo -e "  View logs:        ${YELLOW}kubectl logs -f deployment/mf1-nextjs${NC}"
echo -e "  Scale manually:   ${YELLOW}kubectl scale deployment mf1-nextjs --replicas=5${NC}"
echo -e "\nTo clean up resources, run: ${YELLOW}./cleanup-gke.sh${NC}\n"
