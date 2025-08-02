# API Setup Guide for TTSNewsReader

## Required API Keys

### 1. NewsAPI.org Key
1. Go to [NewsAPI.org](https://newsapi.org/)
2. Sign up for a free account
3. Get your API key from the dashboard
4. Replace `YOUR_NEWS_API_KEY_HERE` in `APIConfiguration.swift`

### 2. Inworld AI TTS Key
1. Go to [Inworld AI](https://www.inworld.ai/)
2. Sign up for an account
3. Navigate to your dashboard/settings
4. Generate a **JWT Key** (NOT Basic auth or JWT Secret)
5. Replace `YOUR_INWORLD_JWT_KEY_HERE` in `APIConfiguration.swift`

⚠️ **Important**: Use JWT Key for client-side authentication as recommended by Inworld AI for mobile apps.

## Configuration Steps

1. Open `TTSNewsReader/Configuration/APIConfiguration.swift`
2. Replace the placeholder values:
   ```swift
   static let newsAPIKey = "your_actual_news_api_key_here"
   static let inworldAPIKey = "your_actual_inworld_jwt_key_here"
   ```

## Testing the App

1. Build and run the app
2. The app will automatically detect if API keys are configured
3. If keys are not set, it will show appropriate error messages
4. For TTS, the app will fall back to system TTS if Inworld AI is not available

## Inworld AI TTS API Reference

- Documentation: https://docs.inworld.ai/docs/tts/tts
- Authentication: Use JWT tokens for client-side apps
- Supported formats: MP3, WAV
- Supported languages: Multiple (configurable in the app)

## Troubleshooting

- **No audio**: Check if API keys are correctly set
- **Network errors**: Verify internet connection and API key validity
- **Audio playback issues**: The app will automatically fall back to system TTS
