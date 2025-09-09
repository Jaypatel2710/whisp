#!/bin/bash

# Whisp Production Deployment Script
# This script helps deploy the Whisp application to production

set -e

echo "🚀 Whisp Production Deployment"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PRODUCTION_API_URL=${PRODUCTION_API_URL:-"https://api.whisp.app"}
PRODUCTION_WS_URL=${PRODUCTION_WS_URL:-"wss://api.whisp.app"}
JWT_SECRET=${JWT_SECRET:-""}
CORS_ORIGIN=${CORS_ORIGIN:-"https://whisp.app"}

echo -e "${BLUE}📋 Production Configuration:${NC}"
echo "  • API URL: $PRODUCTION_API_URL"
echo "  • WebSocket URL: $PRODUCTION_WS_URL"
echo "  • CORS Origin: $CORS_ORIGIN"
echo ""

# Validate JWT secret
if [ -z "$JWT_SECRET" ]; then
    echo -e "${RED}❌ JWT_SECRET environment variable is required for production${NC}"
    echo "Please set JWT_SECRET before running this script:"
    echo "export JWT_SECRET='your-super-secure-jwt-secret-here'"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validated${NC}"

# Build Expo client for production
echo -e "${BLUE}📱 Building Expo client for production...${NC}"
cd clients/expo

# Update production config with environment variables
cat > app.prod.json << EOF
{
  "expo": {
    "name": "Whisp",
    "slug": "whisp-app",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "newArchEnabled": true,
    "splash": {
      "image": "./assets/splash-icon.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.whisp.app"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "edgeToEdgeEnabled": true,
      "package": "com.whisp.app"
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "extra": {
      "apiUrl": "$PRODUCTION_API_URL"
    }
  }
}
EOF

echo -e "${GREEN}✅ Expo production config updated${NC}"
cd ../..

# Build iOS client for production
echo -e "${BLUE}📱 Building iOS client for production...${NC}"
cd clients/ios

# Update Info.plist with production URLs
if [ -f "Whisp/Whisp/Info.plist" ]; then
    sed -i.bak "s|http://localhost:4000|$PRODUCTION_API_URL|g" Whisp/Whisp/Info.plist
    sed -i.bak "s|ws://localhost:4000|$PRODUCTION_WS_URL|g" Whisp/Whisp/Info.plist
    echo -e "${GREEN}✅ iOS production config updated${NC}"
else
    echo -e "${YELLOW}⚠️  iOS Info.plist not found, skipping iOS config${NC}"
fi

cd ../..

# Update Vue client for production
echo -e "${BLUE}🌐 Updating Vue client for production...${NC}"
cd clients/vue

# Create production version with environment variables
cat > index.prod.html << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Whisp Web</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      /* ... existing styles ... */
    </style>
  </head>
  <body>
    <div id="app" class="wrap">
      <!-- ... existing HTML ... -->
    </div>

    <script src="https://unpkg.com/axios/dist/axios.min.js"></script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>
    <script>
      // Production API configuration
      const API_BASE = '$PRODUCTION_API_URL';
      
      // ... existing JavaScript ... */
    </script>
  </body>
</html>
EOF

echo -e "${GREEN}✅ Vue production config updated${NC}"
cd ../..

# Build Android client for production
echo -e "${BLUE}📱 Building Android client for production...${NC}"
cd clients/android

# Update build.gradle.kts with production URLs
if [ -f "app/build.gradle.kts" ]; then
    # Create production build variant
    cat >> app/build.gradle.kts << 'EOF'

android {
    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_BASE_URL", "\"https://api.whisp.app\"")
            buildConfigField("String", "WS_BASE_URL", "\"wss://api.whisp.app\"")
        }
        debug {
            buildConfigField("String", "API_BASE_URL", "\"http://192.168.1.16:4000\"")
            buildConfigField("String", "WS_BASE_URL", "\"ws://192.168.1.16:4000\"")
        }
    }
}
EOF
    echo -e "${GREEN}✅ Android production config updated${NC}"
else
    echo -e "${YELLOW}⚠️  Android build.gradle.kts not found, skipping Android config${NC}"
fi

cd ../..

# Prepare server for production
echo -e "${BLUE}🖥️  Preparing server for production...${NC}"
cd server

# Create production environment file
cat > .env.production << EOF
NODE_ENV=production
PORT=4000
JWT_SECRET=$JWT_SECRET
CORS_ORIGIN=$CORS_ORIGIN
DB_PATH=/var/lib/whisp/anonchat.sqlite
LOG_LEVEL=info
EOF

echo -e "${GREEN}✅ Server production config created${NC}"
cd ..

# Create deployment package
echo -e "${BLUE}📦 Creating deployment package...${NC}"
mkdir -p dist/whisp-production

# Copy server files
cp -r server/* dist/whisp-production/
rm -f dist/whisp-production/node_modules

# Copy client files
mkdir -p dist/whisp-production/clients
cp -r clients/expo dist/whisp-production/clients/
cp -r clients/ios dist/whisp-production/clients/
cp -r clients/android dist/whisp-production/clients/
cp -r clients/vue dist/whisp-production/clients/

# Create production startup script
cat > dist/whisp-production/start-prod.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Whisp Production Server"
npm install --production
npm run prod:env
EOF

chmod +x dist/whisp-production/start-prod.sh

# Create Dockerfile for containerized deployment
cat > dist/whisp-production/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY . .

# Create database directory
RUN mkdir -p /var/lib/whisp

# Expose port
EXPOSE 4000

# Start application
CMD ["npm", "run", "prod:env"]
EOF

echo -e "${GREEN}✅ Deployment package created${NC}"

# Display deployment information
echo ""
echo -e "${GREEN}🎉 Production deployment ready!${NC}"
echo "========================================"
echo -e "${BLUE}📁 Deployment package:${NC} dist/whisp-production/"
echo ""
echo -e "${BLUE}🚀 Deployment options:${NC}"
echo "1. Direct deployment:"
echo "   cd dist/whisp-production && ./start-prod.sh"
echo ""
echo "2. Docker deployment:"
echo "   cd dist/whisp-production"
echo "   docker build -t whisp-app ."
echo "   docker run -p 4000:4000 whisp-app"
echo ""
echo -e "${BLUE}📱 Client Applications:${NC}"
echo "  • Expo: clients/expo (React Native)"
echo "  • iOS: clients/ios/Whisp/Whisp.xcodeproj (Xcode)"
echo "  • Android: clients/android (Android Studio)"
echo "  • Vue: clients/vue/index.prod.html (Web)"
echo ""
echo -e "${BLUE}📋 Environment variables:${NC}"
echo "  • JWT_SECRET: $JWT_SECRET"
echo "  • CORS_ORIGIN: $CORS_ORIGIN"
echo "  • API_URL: $PRODUCTION_API_URL"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "  • Update DNS records to point to your server"
echo "  • Configure SSL certificates for HTTPS"
echo "  • Set up proper firewall rules"
echo "  • Configure database backups"
echo "  • Set up monitoring and logging"
echo ""

echo -e "${GREEN}✅ Production deployment script completed${NC}"
