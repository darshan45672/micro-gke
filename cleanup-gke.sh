#!/bin/bash

# Cleanup script for GKE resources
# This script removes all deployed resources and optionally deletes the cluster

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== GKE Cleanup Script ===${NC}\n"

read -p "Enter your GCP Project ID: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

gcloud config set project $PROJECT_ID

read -p "Enter cluster name (default: micro-frontends-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-micro-frontends-cluster}

read -p "Enter zone (default: us-central1-a): " ZONE
ZONE=${ZONE:-us-central1-a}

# Get cluster credentials
echo -e "\n${YELLOW}Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE 2>/dev/null || true

# Delete Kubernetes resources
echo -e "\n${YELLOW}Deleting Kubernetes resources...${NC}"
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
kubectl delete -f k8s/mf1-hpa.yaml --ignore-not-found=true
kubectl delete -f k8s/mf2-hpa.yaml --ignore-not-found=true
kubectl delete -f k8s/mf1-service.yaml --ignore-not-found=true
kubectl delete -f k8s/mf2-service.yaml --ignore-not-found=true
kubectl delete -f k8s/mf1-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/mf2-deployment.yaml --ignore-not-found=true

# Ask about cluster deletion
echo -e "\n${YELLOW}Do you want to delete the GKE cluster?${NC}"
read -p "This will permanently delete the cluster. Continue? (yes/no): " DELETE_CLUSTER

if [ "$DELETE_CLUSTER" = "yes" ]; then
    echo -e "\n${YELLOW}Deleting GKE cluster...${NC}"
    gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet
    echo -e "${GREEN}Cluster deleted successfully${NC}"
else
    echo -e "${YELLOW}Cluster kept intact${NC}"
fi

# Ask about Docker images
echo -e "\n${YELLOW}Do you want to delete Docker images from Container Registry?${NC}"
read -p "Continue? (yes/no): " DELETE_IMAGES

if [ "$DELETE_IMAGES" = "yes" ]; then
    echo -e "\n${YELLOW}Deleting Docker images...${NC}"
    gcloud container images delete gcr.io/$PROJECT_ID/mf1-nextjs:latest --quiet 2>/dev/null || true
    gcloud container images delete gcr.io/$PROJECT_ID/mf2-vue:latest --quiet 2>/dev/null || true
    echo -e "${GREEN}Images deleted successfully${NC}"
fi

echo -e "\n${GREEN}Cleanup complete!${NC}\n"
