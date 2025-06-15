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
    
    # Get list of local users
    echo ""
    echo -e "${GREEN}Local Users:${NC}"
    LOCAL_USERS=$(rails runner "Actor.where(local: true).pluck(:username).each { |u| puts u }" 2>/dev/null)
    if [ -n "$LOCAL_USERS" ]; then
        echo "$LOCAL_USERS" | while read -r username; do
            if [ -n "$username" ]; then
                echo "  - $username"
            fi
        done
        
        # Test endpoints with first user
        FIRST_USER=$(echo "$LOCAL_USERS" | head -1)
        if [ -n "$FIRST_USER" ]; then
            echo ""
            echo -e "${GREEN}Testing Endpoints (using $FIRST_USER):${NC}"
            
            # Test Actor endpoint
            ACTOR_RESPONSE=$(curl -s -H "Accept: application/activity+json" http://localhost:3000/users/$FIRST_USER | jq -r '.id' 2>/dev/null)
            if [ "$ACTOR_RESPONSE" != "null" ] && [ -n "$ACTOR_RESPONSE" ]; then
                echo "  Actor ID: $ACTOR_RESPONSE"
            else
                echo "  Actor ID: Error accessing endpoint"
            fi
            
            # Test WebFinger
            WEBFINGER_RESPONSE=$(curl -s "http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$DOMAIN" | jq -r '.subject' 2>/dev/null)
            if [ "$WEBFINGER_RESPONSE" != "null" ] && [ -n "$WEBFINGER_RESPONSE" ]; then
                echo "  WebFinger: $WEBFINGER_RESPONSE"
            else
                echo "  WebFinger: Error accessing endpoint"
            fi
        fi
    else
        echo "  No local users found"
        echo "  Create a user with: ./create_user_interactive.sh"
    fi
    
    # Check database stats
    echo ""
    echo -e "${GREEN}Database Statistics:${NC}"
    rails runner "
      puts '  Local actors: ' + Actor.where(local: true).count.to_s
      puts '  Remote actors: ' + Actor.where(local: false).count.to_s
      puts '  Total posts: ' + ActivityPubObject.count.to_s
      puts '  Follow relationships: ' + Follow.count.to_s
      puts '  OAuth applications: ' + Doorkeeper::Application.count.to_s
      puts '  Access tokens: ' + Doorkeeper::AccessToken.count.to_s
    " 2>/dev/null || echo "  Error accessing database"
    
else
    echo -e "${YELLOW}Server Status: Not running${NC}"
    echo "  Use ./start_server.sh to start the server"
fi

# Show process information
echo ""
echo -e "${GREEN}Process Information:${NC}"
RAILS_PROCS=$(ps aux | grep -c "[r]ails server" || echo "0")
QUEUE_PROCS=$(ps aux | grep -c "[s]olid.*queue" || echo "0")
echo "  Rails server processes: $RAILS_PROCS"
echo "  Solid Queue processes: $QUEUE_PROCS"

# Show recent domain history
echo ""
echo -e "${GREEN}Recent Domain History:${NC}"
if [ -f .env ]; then
    grep "^# -" .env | tail -5 | sed 's/^# - /  /' 2>/dev/null || echo "  No history entries found"
else
    echo "  No history available"
fi

# Show available management scripts
echo ""
echo -e "${GREEN}Available Management Scripts:${NC}"
echo "  ./start_server.sh - Start the server"
echo "  ./switch_domain.sh <domain> - Switch to new domain"
echo "  ./create_user_interactive.sh - Create new user"
echo "  ./create_oauth_token.sh - Generate OAuth token"
echo "  ./create_test_posts_multilang.sh - Generate test posts"
echo "  ./cleanup_and_start.sh - Force cleanup and restart"

echo ""
echo -e "${BLUE}========================================${NC}"