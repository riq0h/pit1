#!/bin/bash

# ========================================
# Domain Switch Script for ActivityPub Instance
# ========================================
# This script switches the ActivityPub domain and updates all related URLs
# Usage: ./switch_domain.sh <new_domain> [protocol]
# Example: ./switch_domain.sh abc123.serveo.net https

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <new_domain> [protocol]"
    print_error "Example: $0 abc123.serveo.net https"
    exit 1
fi

NEW_DOMAIN="$1"
NEW_PROTOCOL="${2:-https}"

print_status "Starting domain switch process..."
print_status "New domain: $NEW_DOMAIN"
print_status "Protocol: $NEW_PROTOCOL"

# Get current domain from .env
CURRENT_DOMAIN=$(grep "^ACTIVITYPUB_DOMAIN=" .env | cut -d'=' -f2)
print_status "Current domain: $CURRENT_DOMAIN"

# Confirm the change
echo ""
print_warning "This will:"
echo "  1. Update .env file"
echo "  2. Stop current server"
echo "  3. Update Actor URLs in database"
echo "  4. Restart server with new domain"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled."
    exit 0
fi

print_status "Step 1/5: Updating .env file..."

# Update .env file
sed -i "s/^ACTIVITYPUB_DOMAIN=.*/ACTIVITYPUB_DOMAIN=$NEW_DOMAIN/" .env
sed -i "s/^ACTIVITYPUB_PROTOCOL=.*/ACTIVITYPUB_PROTOCOL=$NEW_PROTOCOL/" .env

print_success ".env file updated"

print_status "Step 2/5: Stopping current server..."

# Stop current server
pkill -f "rails server" 2>/dev/null || true
pkill -f "puma" 2>/dev/null || true
rm -f tmp/pids/server.pid

print_success "Server stopped"

print_status "Step 3/5: Updating Actor URLs in database..."

# Create Ruby script for database update
cat > /tmp/update_actor_for_domain_switch.rb << 'EOF'
# Update all local Actor URLs to new domain
local_actors = Actor.where(local: true)

if local_actors.any?
  new_base_url = Rails.application.config.activitypub.base_url
  puts "Updating #{local_actors.count} local actors to new domain: #{new_base_url}"
  
  local_actors.each do |actor|
    old_ap_id = actor.ap_id
    
    actor.update!(
      ap_id: "#{new_base_url}/users/#{actor.username}",
      inbox_url: "#{new_base_url}/users/#{actor.username}/inbox",
      outbox_url: "#{new_base_url}/users/#{actor.username}/outbox",
      followers_url: "#{new_base_url}/users/#{actor.username}/followers",
      following_url: "#{new_base_url}/users/#{actor.username}/following"
    )
    
    puts "  ✓ Updated #{actor.username}: #{old_ap_id} -> #{actor.ap_id}"
  end
  
  puts "All local actors updated successfully!"
else
  puts "No local actors found"
end
EOF

# Load environment variables and run database update
set -a
source .env
set +a
RAILS_ENV=development rails runner /tmp/update_actor_for_domain_switch.rb

# Clean up temporary file
rm -f /tmp/update_actor_for_domain_switch.rb

print_success "Database URLs updated"

print_status "Step 4/5: Restarting server..."

# Start server with new configuration
./start_server.sh

print_success "Server restarted with new domain"

print_status "Step 5/5: Verifying configuration..."

# Wait a moment for server to start
sleep 3

# Verify the new configuration
print_status "Verification:"
echo "  Server: http://localhost:3000"
echo "  Domain: $NEW_DOMAIN"
echo "  Protocol: $NEW_PROTOCOL"
# Check which users exist and show examples
FIRST_USER=$(rails runner "puts Actor.where(local: true).first&.username" 2>/dev/null)
if [ -n "$FIRST_USER" ]; then
  echo "  Example Actor URL: $NEW_PROTOCOL://$NEW_DOMAIN/users/$FIRST_USER"
  echo "  Example WebFinger: http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$NEW_DOMAIN"
  
  print_success "Domain switch completed successfully!"
  print_warning "You may need to wait a few minutes for external instances to recognize the new domain."
  
  echo ""
  print_status "Test commands:"
  echo "  curl -H \"Accept: application/activity+json\" http://localhost:3000/users/$FIRST_USER | jq '.id'"
  echo "  curl \"http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$NEW_DOMAIN\" | jq '.subject'"
else
  print_success "Domain switch completed successfully!"
  print_warning "No local users found. Create a user with: ./create_user_interactive.sh"
fi