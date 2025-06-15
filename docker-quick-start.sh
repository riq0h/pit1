#!/bin/bash

# Letter ActivityPub Instance - Docker Quick Start
# This script helps you quickly set up and run Letter with Docker

set -e

echo "🚀 Letter ActivityPub Instance - Docker Quick Start"
echo "=================================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Create environment file if it doesn't exist
if [ ! -f ".env.docker.local" ]; then
    echo "📝 Creating environment configuration..."
    cp .env.docker .env.docker.local
    
    echo "⚙️  Please configure your settings in .env.docker.local"
    echo "At minimum, set your ACTIVITYPUB_DOMAIN"
    echo ""
    read -p "Enter your domain (or press Enter for localhost:3000): " domain
    
    if [ -n "$domain" ]; then
        sed -i "s/ACTIVITYPUB_DOMAIN=localhost:3000/ACTIVITYPUB_DOMAIN=$domain/" .env.docker.local
        
        if [[ $domain != *"localhost"* ]]; then
            sed -i "s/ACTIVITYPUB_PROTOCOL=http/ACTIVITYPUB_PROTOCOL=https/" .env.docker.local
        fi
    fi
    
    echo "✅ Environment file created: .env.docker.local"
else
    echo "✅ Environment file exists: .env.docker.local"
fi

echo ""

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p db log public/system/accounts/avatars public/system/accounts/headers public/system/media_attachments
echo "✅ Directories created"
echo ""

# Ask user what to do
echo "What would you like to do?"
echo "1) Build and start Letter (foreground)"
echo "2) Start Letter in background"
echo "3) Build only (don't start)"
echo "4) View logs"
echo "5) Stop Letter"
echo "6) Clean up (remove containers and images)"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "🔨 Building and starting Letter..."
        docker-compose up --build
        ;;
    2)
        echo "🔨 Building and starting Letter in background..."
        docker-compose up -d --build
        echo ""
        echo "✅ Letter is running in background"
        echo "🌐 Access your instance at: http://localhost:3000"
        echo "📊 Health check: http://localhost:3000/up"
        echo ""
        echo "📝 Useful commands:"
        echo "  View logs: docker-compose logs -f"
        echo "  Stop: docker-compose down"
        echo "  Restart: docker-compose restart"
        ;;
    3)
        echo "🔨 Building Letter..."
        docker-compose build
        echo "✅ Build completed"
        ;;
    4)
        echo "📜 Viewing logs..."
        docker-compose logs -f
        ;;
    5)
        echo "🛑 Stopping Letter..."
        docker-compose down
        echo "✅ Letter stopped"
        ;;
    6)
        echo "🧹 Cleaning up..."
        docker-compose down --rmi all --volumes --remove-orphans
        echo "✅ Cleanup completed"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📚 For more information, see DOCKER.md"
echo "🎉 Happy federating!"