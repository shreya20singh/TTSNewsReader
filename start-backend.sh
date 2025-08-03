#!/bin/bash

# TTSNewsReader Backend Startup Script
# This script starts the Node.js backend server for the TTSNewsReader app

echo "🚀 Starting TTSNewsReader Backend Server..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")/backend" || exit 1

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Creating from template..."
    cp .env.example .env
    echo "📝 Please edit backend/.env and add your Inworld AI credentials"
fi

echo "🌍 Backend server will be available at: http://localhost:3000"
echo "📡 Health check: http://localhost:3000/health"
echo "🎤 TTS endpoint: POST http://localhost:3000/tts"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the server
npm run dev
