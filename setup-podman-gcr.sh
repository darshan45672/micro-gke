#!/bin/bash

# Podman Authentication Setup for Google Container Registry (GCR)
# This script helps configure Podman to push images to GCR

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Podman GCR Authentication Setup ===${NC}\n"

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: Podman is not installed${NC}"
    echo "Install it with:"
    echo "  macOS: brew install podman"
    echo "  Linux: See https://podman.io/getting-started/installation"
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
read -p "Enter your GCP Project ID: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Setting up Podman authentication for GCR...${NC}"

# Configure gcloud as credential helper
echo -e "${YELLOW}Configuring gcloud as Docker credential helper...${NC}"
gcloud auth configure-docker

# For Podman, we need to login explicitly
echo -e "\n${YELLOW}Authenticating Podman with GCR...${NC}"

# Get access token from gcloud
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Login to gcr.io with Podman
echo $ACCESS_TOKEN | podman login -u oauth2accesstoken --password-stdin gcr.io

echo -e "\n${GREEN}✓ Authentication successful!${NC}"
echo -e "\nYou can now push images to gcr.io/$PROJECT_ID/"
echo -e "\nExample:"
echo -e "  ${YELLOW}podman build -t gcr.io/$PROJECT_ID/my-app:latest .${NC}"
echo -e "  ${YELLOW}podman push gcr.io/$PROJECT_ID/my-app:latest${NC}"
echo -e "\n${YELLOW}Note: Access tokens expire after ~1 hour. Re-run this script if you get authentication errors.${NC}\n"
