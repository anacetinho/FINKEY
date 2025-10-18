#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo "================================================"
echo "        🗝️  FinKey Personal Finance Setup 🗝️"
echo "================================================"
echo ""
echo "Welcome to FinKey - Your Personal Finance Command Center!"
echo "This script will set up everything you need to get started."
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Docker is installed
echo "[1/4] Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker not found!"
    echo ""
    echo "Please install Docker first:"
    echo "• macOS: https://docs.docker.com/docker-for-mac/install/"
    echo "• Linux: https://docs.docker.com/engine/install/"
    echo ""
    echo "After installation, restart this script."
    exit 1
fi
print_status "Docker found!"

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose not found!"
    echo ""
    echo "Please install Docker Compose:"
    echo "• https://docs.docker.com/compose/install/"
    exit 1
fi
print_status "Docker Compose found!"

# Check if Docker daemon is running
echo ""
echo "[2/4] Checking if Docker is running..."
if ! docker ps &> /dev/null; then
    print_error "Docker daemon is not running!"
    echo ""
    echo "Please start Docker and try again:"
    echo "• macOS: Open Docker Desktop from Applications"
    echo "• Linux: sudo systemctl start docker"
    exit 1
fi
print_status "Docker is running!"

# Setup environment file
echo ""
echo "[3/4] Setting up configuration..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp ".env.example" ".env"
        print_status "Configuration file created (.env from .env.example)"
    else
        print_warning ".env.example not found, creating basic .env"
        cat > .env << EOL
SELF_HOSTED=true
PORT=3000
EOL
    fi
else
    print_info "Configuration file already exists"
fi

# Make sure we have proper permissions on the setup script
chmod +x "$0"

# Start the application
echo ""
echo "[4/4] Starting FinKey..."
echo ""
echo "⏳ This may take 5-10 minutes on first run while Docker downloads and builds everything..."
echo "   You can safely minimize this terminal and check back later."
echo ""

# Use docker-compose or docker compose based on what's available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

$COMPOSE_CMD up -d --build

if [ $? -ne 0 ]; then
    echo ""
    print_error "Failed to start FinKey containers."
    echo ""
    echo "Common solutions:"
    echo "• Make sure Docker is running properly"
    echo "• Check if ports 3000, 5432, or 6379 are already in use"
    echo "• Try: $COMPOSE_CMD down, then run this script again"
    exit 1
fi

# Wait a moment and check container status
echo ""
echo "Waiting for services to start..."
sleep 15

echo ""
echo "📊 Container Status:"
$COMPOSE_CMD ps

echo ""
echo "================================================"
echo "        🎉 FinKey Setup Complete! 🎉"
echo "================================================"
echo ""
echo "🌐 Access your FinKey instance at: http://localhost:3000"
echo ""
echo "💡 Important Notes:"
echo "   • First startup may take 1-2 minutes to initialize database"
echo "   • If you see connection errors, wait a bit longer and refresh"
echo "   • Default port is 3000 (change in .env file if needed)"
echo ""
echo "📋 Useful Commands:"
echo "   • Check status: $COMPOSE_CMD ps"
echo "   • View logs: $COMPOSE_CMD logs"
echo "   • Stop FinKey: $COMPOSE_CMD down"
echo "   • Restart: $COMPOSE_CMD restart"
echo ""
echo "🔧 Need help? Check the documentation in the docs/ folder"
echo ""

# Try to open browser (works on macOS and some Linux distributions)
if command -v open &> /dev/null; then
    echo "Opening http://localhost:3000 in your default browser..."
    open http://localhost:3000
elif command -v xdg-open &> /dev/null; then
    echo "Opening http://localhost:3000 in your default browser..."
    xdg-open http://localhost:3000
else
    echo "Manual step: Open http://localhost:3000 in your browser"
fi

echo ""
echo "Setup complete! Press Enter to exit..."
read -r