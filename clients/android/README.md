# Whisp Android App

A privacy-first ephemeral messaging app for Android built with Jetpack Compose.

## Features

- **Ephemeral Messaging**: Messages exist only while both peers are online
- **Secure Authentication**: Device token-based authentication with secure storage
- **Real-time Communication**: WebSocket-based messaging
- **Privacy-focused**: No message persistence, secure credential storage
- **Modern UI**: Built with Jetpack Compose for a native Android experience

## Architecture

### Core Components

- **MainActivity**: Main app entry point
- **MainScreen**: App coordinator and state management
- **AuthScreen**: User registration and login interface
- **FriendsScreen**: Friends list with online status
- **ChatScreen**: Ephemeral messaging interface
- **APIClient**: REST API communication using Retrofit
- **WebSocketClient**: Real-time messaging using OkHttp WebSocket
- **StorageManager**: Secure credential and token storage using EncryptedSharedPreferences
- **MainViewModel**: State management using ViewModel and StateFlow

### Key Features

1. **Authentication Flow**:
   - Username registration with device token generation
   - Secure token-based login
   - Credentials stored in Android Keystore

2. **Friend Management**:
   - Add friends by username
   - Real-time online status
   - Friend list with presence indicators

3. **Ephemeral Messaging**:
   - Real-time WebSocket communication
   - Messages cleared when app closes
   - No persistent message storage

4. **Security**:
   - Android Keystore for credential storage
   - EncryptedSharedPreferences for sensitive data
   - WebSocket authentication
   - Network security configuration

### User Interface

- **Jetpack Compose**: Modern declarative UI framework
- **Material 3**: Latest Material Design components
- **StateFlow**: Reactive state management
- **Navigation**: Screen-based navigation
- **Responsive Design**: Works on phones and tablets

## Setup

1. **Prerequisites**:
   - Android Studio Arctic Fox or later
   - Android SDK 24+ (API level 24)
   - Kotlin 1.9.0+
   - Whisp server running on localhost:4000

2. **Build & Run**:
   ```bash
   cd clients/android
   ./build.sh  # Optional: build from command line
   # Or open in Android Studio and press Run
   ```

3. **Usage**:
   - Register a new account with a username
   - Save the device token securely
   - Login with username and device token
   - Add friends by their usernames
   - Start ephemeral messaging

## API Integration

The app connects to the Whisp server API endpoints:
- `POST /register` - User registration
- `POST /login` - User authentication
- `POST /friends/add` - Add friend
- `GET /friends` - Get friends list
- `WebSocket /ws` - Real-time messaging

## Network Configuration

- **Development**: Uses `10.0.2.2:4000` (Android emulator localhost)
- **Production**: Uses `https://api.whisp.app`
- **WebSocket**: `ws://10.0.2.2:4000/ws` (dev) or `wss://api.whisp.app/ws` (prod)

## Security

This app implements the core privacy principles of Whisp:
- No message persistence
- Secure credential storage using Android Keystore
- Ephemeral sessions
- Real-time communication only

## Dependencies

- **Retrofit 2.11.0**: HTTP client for API calls
- **OkHttp 4.12.0**: WebSocket and HTTP client
- **Gson 2.10.1**: JSON serialization
- **Jetpack Compose**: Modern UI toolkit
- **Navigation Compose**: Navigation between screens
- **Security Crypto**: Encrypted shared preferences
- **Material 3**: UI components

## Requirements

- Android 7.0 (API level 24) or higher
- Android Studio Arctic Fox or later
- Kotlin 1.9.0 or higher
