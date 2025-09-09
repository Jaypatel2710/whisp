#!/bin/bash

# Whisp Development Environment Startup Script
# This script starts all components for local development

set -e

echo "🚀 Starting Whisp Development Environment"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is in use
port_in_use() {
    lsof -i :$1 >/dev/null 2>&1
}

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command_exists node; then
    echo -e "${RED}❌ Node.js is not installed. Please install Node.js first.${NC}"
    exit 1
fi

if ! command_exists npm; then
    echo -e "${RED}❌ npm is not installed. Please install npm first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Check if ports are available
echo -e "${BLUE}🔍 Checking port availability...${NC}"

if port_in_use 4000; then
    echo -e "${YELLOW}⚠️  Port 4000 is already in use. The server might already be running.${NC}"
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

echo -e "${GREEN}✅ Port 4000 is available${NC}"

# Install dependencies if needed
echo -e "${BLUE}📦 Installing dependencies...${NC}"

# Server dependencies
if [ ! -d "server/node_modules" ]; then
    echo "Installing server dependencies..."
    cd server && npm install && cd ..
fi

# Expo client dependencies
if [ ! -d "clients/expo/node_modules" ]; then
    echo "Installing Expo client dependencies..."
    cd clients/expo && npm install && cd ../..
fi

# Android client dependencies (if Android SDK is available)
if command_exists gradle && [ -d "clients/android" ]; then
    if [ ! -d "clients/android/.gradle" ]; then
        echo "Installing Android client dependencies..."
        cd clients/android && ./gradlew build --no-daemon && cd ../..
    fi
fi

echo -e "${GREEN}✅ Dependencies installed${NC}"

# Start the server
echo -e "${BLUE}🖥️  Starting server...${NC}"
cd server
npm run dev:env &
SERVER_PID=$!
cd ..

# Wait a moment for server to start
sleep 3

# Check if server started successfully
if ! port_in_use 4000; then
    echo -e "${RED}❌ Server failed to start on port 4000${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✅ Server started successfully${NC}"

# Start Expo client
echo -e "${BLUE}📱 Starting Expo client...${NC}"
cd clients/expo
npm run start:dev &
EXPO_PID=$!
cd ../..

echo -e "${GREEN}✅ Expo client started${NC}"

# Display information
echo ""
echo -e "${GREEN}🎉 Development environment is running!${NC}"
echo "========================================"
echo -e "${BLUE}📊 Server Status:${NC}"
echo "  • API URL: http://localhost:4000"
echo "  • WebSocket URL: ws://localhost:4000/ws"
echo "  • Environment: development"
echo ""
echo -e "${BLUE}📱 Client Status:${NC}"
echo "  • Expo Dev Client: Running"
echo "  • Scan QR code with Expo Go app"
echo ""
echo -e "${BLUE}🌐 Web Client:${NC}"
echo "  • Vue client: clients/vue/index.html"
echo "  • Open in browser: file://$(pwd)/clients/vue/index.html"
echo ""
echo -e "${BLUE}📱 iOS Client:${NC}"
echo "  • Open: clients/ios/Whisp/Whisp.xcodeproj"
echo "  • Build and run in Xcode"
echo ""
echo -e "${BLUE}📱 Android Client:${NC}"
echo "  • Open: clients/android in Android Studio"
echo "  • Build and run on device/emulator"
echo "  • Or run: cd clients/android && ./gradlew installDebug"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  • Press Ctrl+C to stop all services"
echo "  • Check logs in terminal for debugging"
echo "  • Use different terminals for each service if needed"
echo ""

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping development environment...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    kill $EXPO_PID 2>/dev/null || true
    echo -e "${GREEN}✅ Development environment stopped${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Wait for user to stop
echo -e "${BLUE}Press Ctrl+C to stop all services${NC}"
wait
