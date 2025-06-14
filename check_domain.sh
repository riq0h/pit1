#!/bin/bash

# ========================================
# Domain Configuration Check Script
# ========================================
# This script checks the current domain configuration

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Current Domain Configuration${NC}"
echo -e "${BLUE}========================================${NC}"

# Check .env file
if [ -f .env ]; then
    DOMAIN=$(grep "^ACTIVITYPUB_DOMAIN=" .env | cut -d'=' -f2)
    PROTOCOL=$(grep "^ACTIVITYPUB_PROTOCOL=" .env | cut -d'=' -f2)
    
    echo -e "${GREEN}Environment Configuration:${NC}"
    echo "  Domain: $DOMAIN"
    echo "  Protocol: $PROTOCOL"
    echo "  Base URL: $PROTOCOL://$DOMAIN"
else
    echo -e "${YELLOW}Warning: .env file not found${NC}"
fi

# Check if server is running
if pgrep -f "rails server\|puma" > /dev/null; then
    echo -e "${GREEN}Server Status: Running${NC}"
    
    # Test endpoints
    echo ""
    echo -e "${GREEN}Testing Endpoints:${NC}"
    
    # Test Actor endpoint
    ACTOR_RESPONSE=$(curl -s -H "Accept: application/activity+json" http://localhost:3000/users/testuser | jq -r '.id' 2>/dev/null)
    if [ "$ACTOR_RESPONSE" != "null" ] && [ -n "$ACTOR_RESPONSE" ]; then
        echo "  Actor ID: $ACTOR_RESPONSE"
    else
        echo "  Actor ID: Error accessing endpoint"
    fi
    
    # Test WebFinger
    WEBFINGER_RESPONSE=$(curl -s "http://localhost:3000/.well-known/webfinger?resource=acct:testuser@$DOMAIN" | jq -r '.subject' 2>/dev/null)
    if [ "$WEBFINGER_RESPONSE" != "null" ] && [ -n "$WEBFINGER_RESPONSE" ]; then
        echo "  WebFinger: $WEBFINGER_RESPONSE"
    else
        echo "  WebFinger: Error accessing endpoint"
    fi
    
else
    echo -e "${YELLOW}Server Status: Not running${NC}"
    echo "  Use ./start_server.sh to start the server"
fi

# Show recent domain history
echo ""
echo -e "${GREEN}Recent Domain History:${NC}"
if [ -f .env ]; then
    grep "^# -" .env | tail -5 | sed 's/^# - /  /'
else
    echo "  No history available"
fi

echo ""
echo -e "${BLUE}========================================${NC}"