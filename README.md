# TTSNewsReader - Personalized Voice News/Feed Reader

A full-stack personalized voice news reader with an iOS SwiftUI app and Node.js backend, providing an immersive news reading experience using Text-to-Speech technology powered by Inworld AI.

## Features

### Core Functionality
- 📰 **News Fetching**: Fetches headlines and summaries from NewsAPI.org
- 🗣️ **Text-to-Speech**: Uses Inworld AI TTS API for expressive speech audio
- 🎵 **Audio Playback**: Smooth audio playback using AVFoundation
- 🌍 **Multi-language Support**: Support for 9 languages including English, Spanish, French, German, Italian, Portuguese, Japanese, Korean, and Chinese

### User Controls
- ⏭️ **Skip**: Move to the next story
- 🔄 **Repeat**: Replay the current story's audio
- 📖 **More on This**: Fetch and read extended content
- 🌐 **Change Language**: Select from supported TTS languages
- ⏸️ **Play/Pause**: Control audio playback

### Analytics & Metrics
- 📊 **Engagement Tracking**: Track listens, skips, repeats, and "more info" requests
- 📈 **Usage Analytics**: View engagement rates and listening patterns
- 💾 **Persistent Preferences**: Save language preferences using UserDefaults

### User Experience
- 📱 **Modern SwiftUI Interface**: Beautiful, responsive design
- 📳 **Haptic Feedback**: Tactile feedback for all user interactions
- 🔍 **Progress Tracking**: Visual indicators for article progress
- 🎨 **Gradient Backgrounds**: Attractive visual design

## Architecture

### **iOS App (Swift, SwiftUI)**
- Fetches news headlines from NewsAPI.org
- Sends text to Node.js backend for TTS generation
- Plays audio using AVFoundation
- Modern SwiftUI interface with haptic feedback
- Analytics and engagement tracking

### **Node.js Backend (Express)**
- RESTful API for TTS generation
- Inworld AI integration following official templates
- Multi-language support
- Error handling and health monitoring
- CORS support for development

## Requirements

### iOS App
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

### Backend Server
- Node.js 16.0+
- npm or yarn
- Inworld AI API credentials

## Setup Instructions

### 1. API Keys Setup

You'll need to obtain API keys for the following services:

#### NewsAPI.org
1. Visit [NewsAPI.org](https://newsapi.org/)
2. Create a free account
3. Get your API key
4. Replace `YOUR_NEWS_API_KEY_HERE` in `Services/NewsService.swift`

#### Inworld AI TTS (Optional - System TTS is used as fallback)
1. Visit [Inworld AI](https://docs.inworld.ai/docs/tts/tts)
2. Create an account and get API access
3. Replace `YOUR_INWORLD_API_KEY_HERE` in `Services/TTSService.swift`
4. Implement the actual Inworld AI API calls (currently using system TTS as fallback)

### 2. Project Setup
1. Clone or download this project
2. Open `TTSNewsReader.xcodeproj` in Xcode
3. Update the API keys as described above
4. Build and run the project

### 3. Permissions
The app automatically requests the following permissions:
- Audio playback permissions (handled by AVAudioSession)

## Architecture

### MVVM Pattern
- **Models**: `NewsArticle`, `MetricsModel`, `TTSLanguage`
- **ViewModels**: `NewsReaderViewModel` (coordinates all services)
- **Views**: `ContentView`, `MetricsView`, `LanguageSelectorView`, `ExtendedContentView`
- **Services**: `NewsService`, `TTSService`, `HapticService`

### Key Components

#### NewsService
- Fetches news from NewsAPI.org
- Supports top headlines and search functionality
- Includes sample data for testing without API keys

#### TTSService
- Integrates with Inworld AI TTS API
- Falls back to system TTS for demonstration
- Manages audio playback and controls

#### MetricsModel
- Tracks user engagement metrics
- Persists language preferences
- Calculates engagement analytics

#### HapticService
- Provides contextual haptic feedback
- Enhances user experience with tactile responses

## File Structure

```
TTSNewsReader/
├── Models/
│   ├── NewsArticle.swift
│   └── MetricsModel.swift
├── Services/
│   ├── NewsService.swift
│   ├── TTSService.swift
│   └── HapticService.swift
├── ViewModels/
│   └── NewsReaderViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── MetricsView.swift
│   ├── LanguageSelectorView.swift
│   └── ExtendedContentView.swift
└── Assets.xcassets/
```

## Usage

### Getting Started
1. Launch the app
2. The app will load sample news articles initially
3. Tap the play button to hear the first article
4. Use the control buttons to navigate and interact

### Navigation
- **Skip**: Move to the next article
- **Previous**: Go back to the previous article
- **Repeat**: Replay the current article
- **More on This**: Get extended content for the current article

### Settings
- **Language Selector**: Tap the globe icon in the header to change TTS language
- **Metrics**: Tap the chart icon to view your usage analytics

### Metrics Tracking
The app automatically tracks:
- Number of headlines listened to
- Articles skipped
- Repeat requests
- "More info" requests
- Language changes
- Engagement rates

## Customization

### Adding New Languages
1. Add new cases to the `TTSLanguage` enum in `Models/NewsArticle.swift`
2. Update the `displayName` computed property
3. Add appropriate flag emoji in `LanguageSelectorView.swift`

### Extending News Sources
1. Modify `NewsService.swift` to support additional news APIs
2. Update the `NewsArticle` model if needed for different response formats
3. Add new search categories or filters

### Custom TTS Voices
1. Implement the Inworld AI API integration in `TTSService.swift`
2. Add voice selection options to the language selector
3. Update the TTS request parameters

## Known Limitations

- **Sample Data**: Currently uses sample data when no API key is provided
- **System TTS**: Falls back to system TTS instead of Inworld AI (implement API integration)
- **Extended Content**: Simulated extended content (implement web scraping or content API)

## Future Enhancements

- 🎙️ **Voice Commands**: Add speech recognition for "skip," "repeat," etc.
- 🔍 **Search Functionality**: Allow users to search for specific topics
- 📂 **Categories**: Add news category filtering
- 💾 **Offline Mode**: Cache articles for offline listening
- 🎵 **Audio Queue**: Queue multiple articles for continuous listening
- 📊 **Advanced Analytics**: More detailed usage insights
- 🌙 **Dark Mode**: Enhanced dark mode support
- 📱 **iPad Support**: Optimize for iPad layouts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is created for educational purposes. Please ensure you comply with the terms of service for NewsAPI.org and Inworld AI when using their services.

## Support

For questions or issues:
1. Check the documentation above
2. Review the code comments
3. Create an issue in the repository

---

Built with ❤️ using SwiftUI and modern iOS development practices.
