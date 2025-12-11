#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping port forwarding for Micro Frontends...${NC}"

# Stop mf1-nextjs port forwarding
if pgrep -f "kubectl port-forward.*mf1-nextjs-service" > /dev/null; then
    pkill -f "kubectl port-forward.*mf1-nextjs-service"
    echo -e "${GREEN}✅ Stopped Next.js port forwarding${NC}"
else
    echo -e "${BLUE}ℹ️  Next.js port forwarding not running${NC}"
fi

# Stop mf2-vuejs port forwarding
if pgrep -f "kubectl port-forward.*mf2-vuejs-service" > /dev/null; then
    pkill -f "kubectl port-forward.*mf2-vuejs-service"
    echo -e "${GREEN}✅ Stopped Vue.js port forwarding${NC}"
else
    echo -e "${BLUE}ℹ️  Vue.js port forwarding not running${NC}"
fi

echo -e "\n${GREEN}🎉 Port forwarding stopped!${NC}"
