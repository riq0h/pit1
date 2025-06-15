#!/bin/bash
set -e

# Letter ActivityPub Instance - Docker Entrypoint
# Handles database setup, environment validation, and process management

echo "=== Letter ActivityPub Instance Starting ==="

# Function to wait for dependencies (if needed in future)
wait_for_dependencies() {
    echo "Checking dependencies..."
    # Future: Add database connection checks if needed
    echo "✓ Dependencies ready"
}

# Validate required environment variables
validate_environment() {
    echo "Validating environment variables..."
    
    if [ -z "$ACTIVITYPUB_DOMAIN" ]; then
        echo "❌ ERROR: ACTIVITYPUB_DOMAIN is required"
        echo "Please set ACTIVITYPUB_DOMAIN in your docker-compose.yml or .env file"
        exit 1
    fi
    
    if [ -z "$ACTIVITYPUB_PROTOCOL" ]; then
        echo "⚠️  WARNING: ACTIVITYPUB_PROTOCOL not set, defaulting to https"
        export ACTIVITYPUB_PROTOCOL=https
    fi
    
    echo "✓ Environment variables validated"
    echo "  Domain: $ACTIVITYPUB_DOMAIN"
    echo "  Protocol: $ACTIVITYPUB_PROTOCOL"
}

# Setup database
setup_database() {
    echo "Setting up database..."
    
    # Check if database exists
    if [ ! -f "db/development.sqlite3" ]; then
        echo "Creating database..."
        bundle exec rails db:create
        bundle exec rails db:migrate
        echo "✓ Database created and migrated"
    else
        echo "Database exists, running migrations..."
        bundle exec rails db:migrate
        echo "✓ Database migrations completed"
    fi
}

# Precompile assets if needed
prepare_assets() {
    echo "Preparing assets..."
    
    # Only precompile if in production or assets don't exist
    if [ "$RAILS_ENV" = "production" ] || [ ! -d "public/assets" ]; then
        echo "Precompiling assets..."
        bundle exec rails assets:precompile
        echo "✓ Assets precompiled"
    else
        echo "✓ Assets already prepared"
    fi
}

# Clean up old processes
cleanup_processes() {
    echo "Cleaning up processes..."
    
    # Remove PID files
    rm -f tmp/pids/server.pid
    rm -f tmp/pids/solid_queue.pid
    
    echo "✓ Process cleanup completed"
}

# Start Solid Queue in background
start_solid_queue() {
    echo "Starting Solid Queue worker..."
    
    # Start Solid Queue as background process
    bundle exec bin/jobs &
    SOLID_QUEUE_PID=$!
    echo $SOLID_QUEUE_PID > tmp/pids/solid_queue.pid
    
    echo "✓ Solid Queue started (PID: $SOLID_QUEUE_PID)"
}

# Graceful shutdown handler
shutdown_handler() {
    echo ""
    echo "=== Shutting down Letter instance ==="
    
    # Stop Solid Queue
    if [ -f tmp/pids/solid_queue.pid ]; then
        SOLID_QUEUE_PID=$(cat tmp/pids/solid_queue.pid)
        if kill -0 $SOLID_QUEUE_PID 2>/dev/null; then
            echo "Stopping Solid Queue (PID: $SOLID_QUEUE_PID)..."
            kill -TERM $SOLID_QUEUE_PID
            wait $SOLID_QUEUE_PID 2>/dev/null || true
        fi
        rm -f tmp/pids/solid_queue.pid
    fi
    
    echo "✓ Graceful shutdown completed"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Main execution
main() {
    wait_for_dependencies
    validate_environment
    cleanup_processes
    setup_database
    prepare_assets
    start_solid_queue
    
    echo "=== Letter ActivityPub Instance Ready ==="
    echo "Starting Rails server..."
    echo "Available at: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
    echo ""
    
    # Execute the main command
    exec "$@"
}

# Run main function
main "$@"