#!/bin/bash

# Load Testing Script for Micro Frontends
# Demonstrates auto-scaling by generating load on the applications

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Load Testing Script for Auto-Scaling Demo ===${NC}\n"

# Get Ingress IP
INGRESS_IP=$(kubectl get ingress micro-frontends-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INGRESS_IP" ]; then
    echo -e "${YELLOW}Ingress IP not found. Make sure your deployment is complete.${NC}"
    exit 1
fi

echo -e "Ingress IP: ${GREEN}$INGRESS_IP${NC}\n"

# Choose target
echo "Which app do you want to load test?"
echo "1) mf1 (Next.js)"
echo "2) mf2 (Vue.js)"
echo "3) Both"
read -p "Enter choice (1-3): " CHOICE

case $CHOICE in
    1)
        TARGET_URL="http://$INGRESS_IP/mf1"
        ;;
    2)
        TARGET_URL="http://$INGRESS_IP/mf2"
        ;;
    3)
        TARGET_URL="http://$INGRESS_IP"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    echo -e "${YELLOW}Installing 'hey' load testing tool...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install hey
    else
        echo "Please install 'hey' manually: https://github.com/rakyll/hey"
        echo "Alternative: use 'ab' (Apache Bench) or 'wrk'"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Starting load test...${NC}"
echo "Open another terminal and run: kubectl get hpa -w"
echo "This will show you the auto-scaling in action!"
echo ""

# Run load test
# 200 requests per second for 2 minutes
hey -z 2m -q 200 -c 50 $TARGET_URL

echo -e "\n${GREEN}Load test complete!${NC}"
echo -e "Check scaling status with: ${YELLOW}kubectl get hpa${NC}"
echo -e "Check pods: ${YELLOW}kubectl get pods${NC}"
