#!/bin/bash

# Whisp Android Build Script
# This script helps build and run the Android app

set -e

echo "🚀 Building Whisp Android App..."

# Check if Android SDK is available
if ! command -v adb &> /dev/null; then
    echo "❌ Android SDK not found. Please install Android Studio and set up the SDK."
    exit 1
fi

# Navigate to the Android project directory
cd "$(dirname "$0")"

# Clean and build the project
echo "🧹 Cleaning project..."
./gradlew clean

echo "🔨 Building project..."
./gradlew assembleDebug

echo "✅ Build completed successfully!"
echo ""
echo "📱 To run the app:"
echo "1. Connect an Android device or start an emulator"
echo "2. Run: ./gradlew installDebug"
echo "3. Or open the project in Android Studio and press Run"
echo ""
echo "🌐 Make sure the server is running on localhost:4000"
echo "   (Android emulator uses 10.0.2.2:4000 to access host localhost)"
