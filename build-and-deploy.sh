#!/bin/bash

# Build and Deploy Micro Frontends to Local Kubernetes
# This script builds Docker images and deploys them to your local k8s cluster

set -e

echo "🚀 Building and Deploying Micro Frontends..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if podman/docker is available
if command -v podman &> /dev/null; then
    CONTAINER_CLI="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CLI="docker"
else
    echo "❌ Neither podman nor docker is installed"
    exit 1
fi

echo -e "${BLUE}Using container CLI: ${CONTAINER_CLI}${NC}"

# Build mf1 (Next.js)
echo -e "\n${GREEN}📦 Building mf1 (Next.js)...${NC}"
cd mf1
$CONTAINER_CLI build -t mf1-nextjs:latest .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ mf1-nextjs image built successfully${NC}"
else
    echo -e "${YELLOW}⚠️  mf1-nextjs build failed${NC}"
    exit 1
fi
cd ..

# Build mf2 (Vue.js)
echo -e "\n${GREEN}📦 Building mf2 (Vue.js)...${NC}"
cd mf2
$CONTAINER_CLI build -t mf2-vuejs:latest .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ mf2-vuejs image built successfully${NC}"
else
    echo -e "${YELLOW}⚠️  mf2-vuejs build failed${NC}"
    exit 1
fi
cd ..

# Load images into cluster
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo -e "\n${BLUE}🔄 Loading images into Minikube...${NC}"
    minikube image load mf1-nextjs:latest
    minikube image load mf2-vuejs:latest
    echo -e "${GREEN}✅ Images loaded into Minikube${NC}"
elif command -v kind &> /dev/null; then
    CURRENT_CONTEXT=$(kubectl config current-context)
    if [[ $CURRENT_CONTEXT == kind-* ]]; then
        CLUSTER_NAME=${CURRENT_CONTEXT#kind-}
        echo -e "\n${BLUE}🔄 Loading images into Kind cluster: ${CLUSTER_NAME}...${NC}"
        
        # For Podman, save and load images via archive
        if [ "$CONTAINER_CLI" = "podman" ]; then
            echo -e "${BLUE}Saving mf1-nextjs image...${NC}"
            podman save localhost/mf1-nextjs:latest -o /tmp/mf1-nextjs.tar
            kind load image-archive /tmp/mf1-nextjs.tar --name ${CLUSTER_NAME}
            rm /tmp/mf1-nextjs.tar
            
            echo -e "${BLUE}Saving mf2-vuejs image...${NC}"
            podman save localhost/mf2-vuejs:latest -o /tmp/mf2-vuejs.tar
            kind load image-archive /tmp/mf2-vuejs.tar --name ${CLUSTER_NAME}
            rm /tmp/mf2-vuejs.tar
        else
            kind load docker-image mf1-nextjs:latest --name ${CLUSTER_NAME}
            kind load docker-image mf2-vuejs:latest --name ${CLUSTER_NAME}
        fi
        
        echo -e "${GREEN}✅ Images loaded into Kind cluster${NC}"
    fi
fi

# Deploy to Kubernetes
echo -e "\n${GREEN}🚀 Deploying to Kubernetes...${NC}"

# Apply deployments
kubectl apply -f k8s/mf1-deployment.yaml
kubectl apply -f k8s/mf2-deployment.yaml

# Optional: Apply ingress if needed
# kubectl apply -f k8s/ingress.yaml

echo -e "\n${GREEN}✅ Deployments created${NC}"

# Wait for deployments to be ready
echo -e "\n${BLUE}⏳ Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/mf1-nextjs
kubectl wait --for=condition=available --timeout=120s deployment/mf2-vuejs

# Get service information
echo -e "\n${GREEN}📋 Service Information:${NC}"
kubectl get services | grep -E "NAME|mf1-nextjs-service|mf2-vuejs-service"

# Get pod status
echo -e "\n${GREEN}📋 Pod Status:${NC}"
kubectl get pods | grep -E "NAME|mf1|mf2"

# Display access information
echo -e "\n${GREEN}🎉 Deployment Complete!${NC}"
echo -e "\n${BLUE}Access your applications:${NC}"

# Get NodePort URLs
MF1_PORT=$(kubectl get service mf1-nextjs-service -o jsonpath='{.spec.ports[0].nodePort}')
MF2_PORT=$(kubectl get service mf2-vuejs-service -o jsonpath='{.spec.ports[0].nodePort}')

CURRENT_CONTEXT=$(kubectl config current-context)
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    MINIKUBE_IP=$(minikube ip)
    echo -e "${GREEN}Next.js Landing Page:${NC} http://${MINIKUBE_IP}:${MF1_PORT}"
    echo -e "${GREEN}Vue.js Blog Listing:${NC} http://${MINIKUBE_IP}:${MF2_PORT}"
elif [[ $CURRENT_CONTEXT == kind-* ]]; then
    echo -e "${GREEN}Next.js Landing Page:${NC} http://localhost:${MF1_PORT}"
    echo -e "${GREEN}Vue.js Blog Listing:${NC} http://localhost:${MF2_PORT}"
    echo -e "${BLUE}Cluster:${NC} ${CURRENT_CONTEXT}"
else
    echo -e "${GREEN}Next.js Landing Page:${NC} http://localhost:${MF1_PORT}"
    echo -e "${GREEN}Vue.js Blog Listing:${NC} http://localhost:${MF2_PORT}"
fi

echo -e "\n${YELLOW}Note: Update the URLs in your applications if they differ from development ports${NC}"
