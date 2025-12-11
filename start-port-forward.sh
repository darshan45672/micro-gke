#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Setting up port forwarding for Micro Frontends...${NC}"

# Check if port forwarding is already running
if pgrep -f "kubectl port-forward.*mf1-nextjs-service" > /dev/null; then
    echo -e "${YELLOW}⚠️  Port forwarding for mf1-nextjs already running${NC}"
else
    echo -e "${BLUE}Setting up port forwarding for Next.js (30001 -> 3000)...${NC}"
    kubectl port-forward service/mf1-nextjs-service 30001:3000 > /tmp/mf1-port-forward.log 2>&1 &
    MF1_PID=$!
    echo -e "${GREEN}✅ Next.js port forwarding started (PID: $MF1_PID)${NC}"
fi

if pgrep -f "kubectl port-forward.*mf2-vuejs-service" > /dev/null; then
    echo -e "${YELLOW}⚠️  Port forwarding for mf2-vuejs already running${NC}"
else
    echo -e "${BLUE}Setting up port forwarding for Vue.js (30002 -> 80)...${NC}"
    kubectl port-forward service/mf2-vuejs-service 30002:80 > /tmp/mf2-port-forward.log 2>&1 &
    MF2_PID=$!
    echo -e "${GREEN}✅ Vue.js port forwarding started (PID: $MF2_PID)${NC}"
fi

# Wait a moment for port forwarding to be ready
sleep 2

echo -e "\n${GREEN}🎉 Port forwarding setup complete!${NC}"
echo -e "\n${BLUE}📋 Access your micro frontends:${NC}"
echo -e "   Next.js Landing Page: ${GREEN}http://localhost:30001${NC}"
echo -e "   Vue.js Blog Listing:  ${GREEN}http://localhost:30002${NC}"
echo -e "\n${BLUE}💡 Tips:${NC}"
echo -e "   - Port forwarding will continue in the background"
echo -e "   - To stop: run ${YELLOW}./stop-port-forward.sh${NC}"
echo -e "   - To check status: run ${YELLOW}jobs${NC}"
echo -e "   - View logs: ${YELLOW}tail -f /tmp/mf1-port-forward.log${NC}"
