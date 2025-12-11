#!/bin/bash

# Update Application URLs for Kubernetes Deployment
# This script updates the hardcoded URLs in the applications to use NodePort services

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔧 Updating Application URLs for Kubernetes...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Get NodePort values
MF1_PORT=$(kubectl get service mf1-nextjs-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
MF2_PORT=$(kubectl get service mf2-vuejs-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

if [ -z "$MF1_PORT" ] || [ -z "$MF2_PORT" ]; then
    echo -e "${YELLOW}⚠️  Services not found. Please deploy the applications first.${NC}"
    exit 1
fi

# Determine cluster IP
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    CLUSTER_IP=$(minikube ip)
    echo -e "${GREEN}Using Minikube IP: ${CLUSTER_IP}${NC}"
else
    CLUSTER_IP="localhost"
    echo -e "${GREEN}Using localhost${NC}"
fi

MF1_URL="http://${CLUSTER_IP}:${MF1_PORT}"
MF2_URL="http://${CLUSTER_IP}:${MF2_PORT}"

echo -e "\n${BLUE}URLs to be configured:${NC}"
echo -e "Next.js (mf1): ${MF1_URL}"
echo -e "Vue.js (mf2): ${MF2_URL}"

# Update Vue.js App
echo -e "\n${GREEN}📝 Updating Vue.js app (mf2/src/App.vue)...${NC}"
if [ -f "mf2/src/App.vue" ]; then
    # Backup original file
    cp mf2/src/App.vue mf2/src/App.vue.bak
    
    # Update the navigateToLanding function
    sed -i.tmp "s|window.location.href = 'http://localhost:3000'|window.location.href = '${MF1_URL}'|g" mf2/src/App.vue
    rm -f mf2/src/App.vue.tmp
    
    echo -e "${GREEN}✅ Vue.js app updated${NC}"
else
    echo -e "${YELLOW}⚠️  mf2/src/App.vue not found${NC}"
fi

# Update Next.js App
echo -e "\n${GREEN}📝 Updating Next.js app (mf1/app/page.tsx)...${NC}"
if [ -f "mf1/app/page.tsx" ]; then
    # Backup original file
    cp mf1/app/page.tsx mf1/app/page.tsx.bak
    
    # Update the href in the Link component
    sed -i.tmp "s|href=\"http://localhost:5173\"|href=\"${MF2_URL}\"|g" mf1/app/page.tsx
    rm -f mf1/app/page.tsx.tmp
    
    echo -e "${GREEN}✅ Next.js app updated${NC}"
else
    echo -e "${YELLOW}⚠️  mf1/app/page.tsx not found${NC}"
fi

echo -e "\n${BLUE}📦 Now rebuild and redeploy the applications:${NC}"
echo -e "1. Run: ${GREEN}./build-and-deploy.sh${NC}"
echo -e "2. Or manually rebuild images and update deployments"

echo -e "\n${YELLOW}Note: Original files backed up as *.bak${NC}"
echo -e "${YELLOW}To restore: cp mf2/src/App.vue.bak mf2/src/App.vue${NC}"
echo -e "${YELLOW}           cp mf1/app/page.tsx.bak mf1/app/page.tsx${NC}"
