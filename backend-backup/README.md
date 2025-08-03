# TTSNewsReader Backend

Node.js Express server that provides Text-to-Speech services for the TTSNewsReader iOS app using Inworld AI.

## Features

- **TTS Generation**: Convert text to speech using Inworld AI
- **Multi-language Support**: Support for 9 languages matching the iOS app
- **RESTful API**: Clean API endpoints for TTS and voice management
- **Error Handling**: Comprehensive error handling and logging
- **CORS Support**: Configured for local development
- **Health Monitoring**: Health check endpoint for service monitoring

## API Endpoints

### `GET /health`
Health check endpoint
```json
{
  "status": "ok",
  "timestamp": "2025-08-02T22:51:04.000Z",
  "inworldConnected": true
}
```

### `GET /voices`
Get supported voices and languages
```json
{
  "success": true,
  "voices": [
    {
      "code": "en-US",
      "name": "English (US)",
      "voice": "default"
    }
  ]
}
```

### `POST /tts`
Generate TTS audio from text

**Request Body:**
```json
{
  "text": "Hello, this is a news story...",
  "language": "en-US",
  "voice": "default"
}
```

**Response:**
- Success: Binary audio data (WAV format)
- Error: JSON error response

## Setup Instructions

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Environment Configuration
1. Copy `.env.example` to `.env`
2. Fill in your Inworld AI credentials:
```env
INWORLD_API_KEY=your_inworld_api_key_here
INWORLD_WORKSPACE_ID=your_workspace_id_here
INWORLD_SCENE_ID=your_scene_id_here
```

### 3. Get Inworld AI Credentials
1. Visit [Inworld AI](https://docs.inworld.ai/docs/tts/tts)
2. Create an account and get your API credentials
3. Set up a workspace and scene for TTS

### 4. Run the Server
```bash
# Development mode (with auto-restart)
npm run dev

# Production mode
npm start
```

The server will start on `http://localhost:3000` by default.

## Development

### Project Structure
```
backend/
├── server.js          # Main server file
├── package.json       # Dependencies and scripts
├── .env.example       # Environment variables template
└── README.md          # This file
```

### Testing the API
```bash
# Health check
curl http://localhost:3000/health

# Get supported voices
curl http://localhost:3000/voices

# Generate TTS (save to file)
curl -X POST http://localhost:3000/tts \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world","language":"en-US"}' \
  --output test.wav
```

## Integration with iOS App

The iOS app's `TTSService.swift` should be updated to call this backend instead of calling Inworld AI directly:

```swift
// Instead of calling Inworld directly, call:
// POST http://localhost:3000/tts
// with JSON body: {"text": "...", "language": "en-US"}
```

## Error Handling

The server includes comprehensive error handling:
- Input validation
- Inworld API error handling
- Graceful shutdown
- Development vs production error responses

## Security Considerations

- API keys are stored in environment variables
- CORS is configured for development
- Request size limits are enforced
- Helmet.js provides security headers

## Deployment

For production deployment:
1. Set `NODE_ENV=production`
2. Configure appropriate CORS origins
3. Use a process manager like PM2
4. Set up proper logging and monitoring
