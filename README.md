# Whisp - Ephemeral Messaging

A privacy-first messaging app with zero server storage. Messages exist only while both peers are online, then vanish completely.

## Core Principles

- **No content on servers**: Server only handles discovery + signaling; never sees message payloads
- **Ephemeral sessions**: Chats exist only while both peers are online; session keys die when either leaves
- **Identity = keys, not PII**: Usernames are public aliases; trust is anchored in device/account keys
- **Metadata minimization**: Store only what's essential for reachability; aggressively rotate/expire the rest

## Architecture

### System Components

- **Directory/Signaling Server**: Maps usernames to online devices (volatile in-memory store)
- **TURN/STUN**: NAT traversal for P2P; fallback to TURN relay (still E2E-encrypted)
- **Clients**: Hold keys, contact list, and minimal logs locally; establish WebRTC data channels

### Key Management

- **Account Keypair (AK)**: Ed25519 for identity (long-term, per user)
- **Device Keypair (DK)**: Ed25519 + Curve25519 for device auth and ECDH
- **Pre-keys**: Short-lived X25519 bundles advertised only while online
- **Session Keys**: Derived via X3DH → Double Ratchet for continuous PFS

## User Flow

### Account Setup

1. Generate AK, DK, and initial pre-key bundle
2. Choose username (check availability)
3. Server records: username, AK_pub, deviceID, DK_pub (no private keys, no PII)
4. Device stores private keys locally (Secure Enclave/KeyStore)

### Multi-Device Support

- **QR Handoff**: Old device displays enrollment token (signed with AK_priv)
- **OTP Handoff**: Remote device addition with signed token

### Contacting Someone

1. Enter username → server returns online status + safety number
2. If online, request session → server forwards connection request
3. Both sides fetch pre-keys and run X3DH/Noise key exchange
4. Switch to Double Ratchet on P2P channel

## Messaging

- **Transport**: WebRTC DataChannel or QUIC
- **Encryption**: Double Ratchet with PFS + post-compromise security
- **Storage**: Messages only in memory (ring buffer), cleared on disconnect
- **No persistence**: App close/OS kill/lock → buffer cleared

## Privacy & Security

### What Server Stores

- **Persistent**: username, AK_pub, deviceID, DK_pub, push tokens
- **Ephemeral**: Online presence, pre-key bundles, session offers
- **Never**: Messages, contact lists, safety numbers, IP logs

### Threat Mitigations

- **Server compromise**: Only public keys leak—no content or history
- **MITM prevention**: Authenticated AKE + safety number verification
- **Metadata protection**: TURN-only mode to hide peer IPs
- **Spam prevention**: Rate limits + proof-of-work for first contact
- **Device loss**: Revoke device with signed revocation from another device

## Tech Stack

- **Mobile**:
  - **Android**: Kotlin + Jetpack Compose + Retrofit + OkHttp
  - **iOS**: Swift + SwiftUI + Combine + URLSession
  - **Cross-platform**: React Native + Expo
- **Web**: Vue.js 3 + Axios
- **Transport**: WebSocket + HTTP REST API
- **Crypto**: Android Keystore + iOS Keychain + JWT
- **Server**: Node.js + Express + SQLite
- **Push**: APNs / FCM with opaque tokens

## MVP Features

- ✅ **Cross-platform clients**: Android, iOS, Expo, Vue web
- ✅ **Account creation and username claim**
- ✅ **Device key generation and secure storage**
- ✅ **Real-time ephemeral messaging via WebSocket**
- ✅ **In-memory ephemeral sessions**
- ✅ **Friend management system**
- ✅ **Environment-based configuration**
- ✅ **Secure credential storage**
- 🔄 Multi-device support via QR handoff
- 🔄 Friend requests with safety number verification
- 🔄 WebRTC messaging with Double Ratchet encryption
- 🔄 TURN fallback and push notifications
- 🔄 Device revocation and panic close

## Discovery Modes

### Privacy Levels

1. **Public**: Directory shows username + online/offline status
2. **Default**: Username-only lookup, no public directory  
3. **Strict**: Username + Friend Verification Code (FVC) required

### Friend Verification Code (FVC)

- **TOTP-based**: Time-based codes (60-120s windows)
- **Static**: One-time printed codes
- **Privacy-first**: Server verifies without storing secrets

## Competitor Analysis

### Key Players

- **Wickr Me**: Zero-knowledge logs, millisecond ephemeral chats
- **Confide**: Screenshot-proof, self-destructing messages  
- **Snapchat**: Mainstream ephemeral messaging
- **Telegram Secret Chats**: E2EE with self-destruct timers
- **Session**: Decentralized, no PII required

### Our Differentiation

- Live ephemeral messaging with zero storage anywhere
- Strict control over presence & history
- Flexible discovery modes with FVC
- Real-time camera capture without disk storage

## Development Roadmap

### Phase 1: Core MVP

- Account creation and device management
- WebRTC messaging with Double Ratchet
- In-memory ephemeral sessions
- Basic friend system

### Phase 2: Privacy Basics

- Auto-delete timers (5s, 1m, 1h, 1d)
- Server minimalism (presence only)
- Panic close functionality

### Phase 3: Trust & Control

- Screenshot protection
- Safety number verification
- Friend Verification Codes

### Phase 4: Feature Parity

- Self-destructing media
- Presence controls
- Multi-device support

### Phase 5: Differentiators

- Custom discovery modes
- Metadata hiding (TURN-only)
- Group ephemeral chats

### Phase 6: Advanced Privacy

- E2E encryption implementation
- Chunked file transfer
- Decentralized relays

## Environment Configuration

The Whisp application supports multiple environments with flexible configuration:

### Quick Start (Development)

```bash
# Start all services for local development
./start-dev.sh
```

### Environment-Specific Configuration

- **Development**: Localhost URLs, debug logging, relaxed CORS
- **Staging**: Pre-production testing with staging URLs
- **Production**: Optimized performance, secure configuration

### Client Configuration

- **Expo**: Environment-specific `app.json` files
- **Vue**: Automatic hostname detection with fallbacks
- **iOS**: Build configurations and Info.plist settings
- **Android**: Build variants and environment-specific URLs

### Server Configuration

- **Environment Variables**: `NODE_ENV`, `PORT`, `JWT_SECRET`, `CORS_ORIGIN`
- **Environment Files**: `env.development`, `env.production`
- **Scripts**: `npm run dev:env`, `npm run prod:env`

For detailed configuration instructions, see [ENVIRONMENT_CONFIG.md](./ENVIRONMENT_CONFIG.md).

## Deployment

### Development

```bash
# Start all services for local development
./start-dev.sh
```

### Production

```bash
# Set required environment variables
export JWT_SECRET="your-super-secure-jwt-secret"
export CORS_ORIGIN="https://yourdomain.com"

# Deploy all clients and server
./deploy-prod.sh
```

## 📱 Client Applications

### Android

- **Technology**: Kotlin + Jetpack Compose
- **Build**: `cd clients/android && ./gradlew assembleDebug`
- **Run**: Open in Android Studio or `./gradlew installDebug`

### iOS

- **Technology**: Swift + SwiftUI
- **Build**: Open `clients/ios/Whisp/Whisp.xcodeproj` in Xcode
- **Run**: Build and run on device/simulator

### Expo (Cross-platform)

- **Technology**: React Native + Expo
- **Build**: `cd clients/expo && npm run start:dev`
- **Run**: Scan QR code with Expo Go app

### Vue (Web)

- **Technology**: Vue.js 3 + Axios
- **Build**: Open `clients/vue/index.html` in browser
- **Run**: Serve from any web server
