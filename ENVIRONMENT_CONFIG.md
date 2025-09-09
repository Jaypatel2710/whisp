# Environment Configuration Guide

This document explains how to configure the Whisp application for different environments (development, staging, production).

## 🌍 Environment Overview

The Whisp application supports multiple environments with different configurations:

- **Development**: Local development with localhost URLs
- **Staging**: Pre-production testing environment
- **Production**: Live production environment

## 📱 Client Configuration

### Expo Client

The Expo client uses different `app.json` files for different environments:

#### Development

```bash
# Use development configuration
npm run start:dev
# or
expo start --config app.dev.json
```

**Configuration**: `app.dev.json`

- API URL: `http://localhost:4000`
- App Name: "whisp-client-expo (Dev)"

#### Production

```bash
# Use production configuration
npm run start:prod
# or
expo start --config app.prod.json
```

**Configuration**: `app.prod.json`

- API URL: `https://api.whisp.app`
- App Name: "Whisp"
- Bundle ID: `com.whisp.app`

### Vue Client

The Vue client automatically detects the environment based on the hostname:

- `localhost` or `127.0.0.1` → Development (`http://localhost:4000`)
- `staging.*` → Staging (`https://staging-api.whisp.app`)
- Other domains → Production (`https://api.whisp.app`)

You can also set `window.ENV.API_URL` to override the automatic detection.

### iOS Client

The iOS client uses build configurations and Info.plist settings:

#### Development Build

- API URL: `http://localhost:4000`
- WebSocket URL: `ws://localhost:4000`
- Configuration: Debug build

#### Production Build

- API URL: `https://api.whisp.app`
- WebSocket URL: `wss://api.whisp.app`
- Configuration: Release build

**Custom Configuration**: Update `Info.plist` with your URLs:

```xml
<key>API_BASE_URL</key>
<string>https://your-api-domain.com</string>
<key>WS_BASE_URL</key>
<string>wss://your-api-domain.com</string>
```

### Android Client

The Android client uses build variants and environment-specific configuration:

#### Development Build

- API URL: `http://192.168.1.16:4000` (configurable IP)
- WebSocket URL: `ws://192.168.1.16:4000`
- Configuration: Debug build variant
- Build Type: `debug`

#### Production Build

- API URL: `https://api.whisp.app`
- WebSocket URL: `wss://api.whisp.app`
- Configuration: Release build variant
- Build Type: `release`

**Custom Configuration**: Update `APIClient.kt` and `WebSocketClient.kt`:

```kotlin
// In APIClient.kt
baseUrl = if (BuildConfig.DEBUG) {
    "http://your-dev-server:4000"
} else {
    "https://api.whisp.app"
}

// In WebSocketClient.kt
baseUrl = if (BuildConfig.DEBUG) {
    "ws://your-dev-server:4000"
} else {
    "wss://api.whisp.app"
}
```

**Build Commands**:

```bash
# Development build
./gradlew assembleDebug

# Production build
./gradlew assembleRelease

# Install on device
./gradlew installDebug
```

## 🖥️ Server Configuration

### Environment Variables

The server supports the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `development` | Environment mode |
| `PORT` | `4000` | Server port |
| `JWT_SECRET` | `dev-secret-change` | JWT signing secret |
| `CORS_ORIGIN` | `*` | Allowed CORS origins |
| `DB_PATH` | `./anonchat.sqlite` | Database file path |

### Running the Server

#### Development

```bash
# Using environment file
npm run dev:env

# Using environment variables
NODE_ENV=development PORT=4000 npm run dev
```

#### Production

```bash
# Using environment file
npm run prod:env

# Using environment variables
NODE_ENV=production PORT=4000 JWT_SECRET=your-secret npm start
```

### Environment Files

#### Development (`env.development`)

```env
NODE_ENV=development
PORT=4000
JWT_SECRET=dev-secret-change-this-in-production
CORS_ORIGIN=*
DB_PATH=./anonchat.sqlite
LOG_LEVEL=debug
```

#### Production (`env.production`)

```env
NODE_ENV=production
PORT=4000
JWT_SECRET=your-super-secure-jwt-secret-here
CORS_ORIGIN=https://whisp.app,https://api.whisp.app
DB_PATH=/var/lib/whisp/anonchat.sqlite
LOG_LEVEL=info
```

## 🚀 Deployment Examples

### Local Development

```bash
# Option 1: Use the convenience script
./start-dev.sh

# Option 2: Manual setup
# Terminal 1: Start server
cd server
npm run dev:env

# Terminal 2: Start Expo client
cd clients/expo
npm run start:dev

# Terminal 3: Start Android client (if Android SDK available)
cd clients/android
./gradlew installDebug

# Terminal 4: Start Vue client (if needed)
# Serve the Vue client from a local web server
```

### Staging Deployment

```bash
# Server
NODE_ENV=staging PORT=4000 CORS_ORIGIN=https://staging.whisp.app npm start

# Clients
# Update client configurations to point to staging URLs
```

### Production Deployment

```bash
# Server
npm start
```

## Clients

### Use production build configurations

#### 🔧 Custom Configuration

##### Adding New Environments

1. **Expo**: Create new `app.{env}.json` files
2. **Vue**: Add hostname detection logic
3. **iOS**: Add new build configurations in Xcode
4. **Android**: Add new build variants in `build.gradle.kts`
5. **Server**: Create new environment files

##### Environment-Specific Features

- **Development**: Debug logging, localhost URLs, relaxed CORS
- **Staging**: Production-like setup with test data
- **Production**: Optimized performance, secure configuration

### 📋 Checklist for New Environments

- [ ] Create environment-specific configuration files
- [ ] Update API URLs in all clients
- [ ] Configure CORS origins on server
- [ ] Set appropriate JWT secrets
- [ ] Update database paths
- [ ] Test all client-server communication
- [ ] Verify WebSocket connections
- [ ] Check security settings

## 🛡️ Security Considerations

- **JWT Secrets**: Use strong, unique secrets for each environment
- **CORS**: Restrict origins in production
- **Database**: Use secure file paths and permissions
- **Logging**: Adjust log levels for production
- **HTTPS**: Use secure connections in production

## 🔍 Troubleshooting

### Common Issues

1. **CORS Errors**: Check `CORS_ORIGIN` configuration
2. **Connection Refused**: Verify server is running and port is correct
3. **WebSocket Issues**: Check WebSocket URL configuration
4. **Authentication Failures**: Verify JWT secret consistency

### Debug Commands

```bash
# Check server configuration
npm run dev:env

# Test API endpoints
curl http://localhost:4000/users

# Check WebSocket connection
# Use browser dev tools or WebSocket testing tools
```
