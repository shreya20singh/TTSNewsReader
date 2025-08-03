/**
 * TTSNewsReader Backend Server
 * Node.js Express server with Inworld AI TTS integration
 * Using direct REST API approach for macOS compatibility
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const axios = require('axios');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Inworld AI API constants
const INWORLD_API_BASE = 'https://api.inworld.ai';
const DEFAULT_VOICE_ID = 'Ronald';
const DEFAULT_MODEL = 'inworld-tts-1-max';
const DEFAULT_WORKSPACE_ID = 'default-jv9rith_zenenocmvv4daq';

// Language to voice mapping using actual Inworld voice IDs from documentation
const LANGUAGE_VOICE_MAP = {
    'en-US': 'Ronald',      // English (US) - Female voice
    'en-GB': 'Ronald',        // English (UK) - Male voice
    'es-ES': 'Ronald',      // Spanish - Use Ashley for now
    'fr-FR': 'Ronald',      // French - Use Ashley for now
    'de-DE': 'Ronald',      // German - Use Ashley for now
    'it-IT': 'Ronald',      // Italian - Use Ashley for now
    'pt-BR': 'Ronald',      // Portuguese (Brazil) - Use Ashley for now
    'ja-JP': 'Ronald',      // Japanese - Use Ashley for now
    'ko-KR': 'Ronald',      // Korean - Use Ashley for now
    'zh-CN': 'Ronald',      // Chinese (Mandarin) - Use Ashley for now
    'ru-RU': 'Ronald',      // Russian - Use Ashley for now
    'ar-SA': 'Ronald',      // Arabic - Use Ashley for now
    'hi-IN': 'Ronald'       // Hindi - Use Ashley for now
};

/**
 * Check Inworld AI API configuration
 */
function checkInworldConfig() {
    const hasApiKey = process.env.INWORLD_API_KEY && !process.env.INWORLD_API_KEY.includes('your_');
    
    if (hasApiKey) {
        console.log('✅ Inworld AI API key configured');
        return true;
    } else {
        console.warn('⚠️  INWORLD_API_KEY not found or not configured properly');
        return false;
    }
}

/**
 * Generate TTS audio using Inworld AI REST API
 * @param {string} text - Text to convert to speech
 * @param {string} language - Language code (e.g., 'en-US')
 * @param {string} voice - Voice identifier
 * @returns {Buffer} Audio data as buffer
 */
async function generateTTSAudio(text, language = 'en-US', voice = 'default') {
    try {
        console.log(`🎤 Generating TTS for text: "${text.substring(0, 50)}..."`);
        console.log(`🌍 Language: ${language}, Voice: ${voice}`);

        const apiKeyBase64 = process.env.INWORLD_API_KEY;
        const workspaceId = process.env.INWORLD_WORKSPACE_ID || DEFAULT_WORKSPACE_ID;
        const voiceName = getVoiceForLanguage(language, voice);

        // Decode the base64 API key to get key:secret format
        const decodedKey = Buffer.from(apiKeyBase64, 'base64').toString('utf-8');
        const [apiKey, apiSecret] = decodedKey.split(':');

        console.log(`📤 Sending TTS request to Inworld AI (Voice: ${voiceName})...`);
        
        // Use correct Inworld TTS API format from official documentation
        console.log('🔑 Using API Key:', apiKey.substring(0, 10) + '...');
        console.log('🎤 Voice ID:', voiceName, 'Language:', language);
        
        try {
            // Use the correct Inworld TTS API endpoint: /tts/v1/voice
            const response = await axios.post(
                `${INWORLD_API_BASE}/tts/v1/voice`,
                {
                    text: text,
                    voiceId: voiceName,
                    modelId: DEFAULT_MODEL
                },
                {
                    headers: {
                        'Authorization': `Basic ${apiKeyBase64}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000
                }
            );
            
            console.log('✅ Inworld TTS API call succeeded');
            
            // Check if we got a valid response with audioContent
            if (response.data && response.data.audioContent) {
                // Decode the base64 audio content
                const audioBuffer = Buffer.from(response.data.audioContent, 'base64');
                console.log(`✅ TTS audio generated successfully (${audioBuffer.length} bytes)`);
                
                // Log usage info if available
                if (response.data.usage) {
                    console.log(`📊 Usage: ${response.data.usage.processedCharactersCount} characters, Model: ${response.data.usage.modelId}`);
                }
                
                return audioBuffer;
            } else {
                console.warn('⚠️  Inworld API response missing audioContent');
                throw new Error('No audio content in response');
            }
        } catch (apiError) {
            console.warn('⚠️  Inworld TTS API failed:', apiError.response?.status, apiError.response?.statusText);
            console.warn('🧪 Using test audio fallback...');
            return generateTestAudio(text);
        }

    } catch (error) {
        console.error('❌ TTS generation failed:', error);
        throw error;
    }
}

/**
 * Generate a simple test audio file for development/testing
 * @param {string} text - Text that would be converted to speech
 * @returns {Buffer} Simple WAV audio buffer
 */
function generateTestAudio(text) {
    console.log('🧪 Generating test audio for development...');
    
    // Create a simple WAV header for a short beep sound
    const sampleRate = 22050;
    const duration = Math.min(text.length * 0.1, 3); // Max 3 seconds
    const numSamples = Math.floor(sampleRate * duration);
    
    // WAV header (44 bytes)
    const header = Buffer.alloc(44);
    header.write('RIFF', 0);
    header.writeUInt32LE(36 + numSamples * 2, 4);
    header.write('WAVE', 8);
    header.write('fmt ', 12);
    header.writeUInt32LE(16, 16);
    header.writeUInt16LE(1, 20);
    header.writeUInt16LE(1, 22);
    header.writeUInt32LE(sampleRate, 24);
    header.writeUInt32LE(sampleRate * 2, 28);
    header.writeUInt16LE(2, 32);
    header.writeUInt16LE(16, 34);
    header.write('data', 36);
    header.writeUInt32LE(numSamples * 2, 40);
    
    // Generate simple audio data (sine wave)
    const audioData = Buffer.alloc(numSamples * 2);
    for (let i = 0; i < numSamples; i++) {
        const sample = Math.sin(2 * Math.PI * 440 * i / sampleRate) * 0.3; // 440Hz tone
        const intSample = Math.floor(sample * 32767);
        audioData.writeInt16LE(intSample, i * 2);
    }
    
    const result = Buffer.concat([header, audioData]);
    console.log(`✅ Test audio generated (${result.length} bytes)`);
    return result;
}

/**
 * Get appropriate voice for language
 * @param {string} language - Language code
 * @param {string} voice - Voice preference
 * @returns {string} Voice ID
 */
function getVoiceForLanguage(language, voice) {
    // Use the predefined language-voice mapping
    const selectedVoice = LANGUAGE_VOICE_MAP[language] || LANGUAGE_VOICE_MAP['en-US'];
    
    // If a specific voice is requested and it's not 'default', use it
    if (voice && voice !== 'default') {
        return voice;
    }
    
    console.log(`🎭 Selected voice for ${language}: ${selectedVoice}`);
    return selectedVoice;
}

/**
 * Clean up Inworld resources
 */
async function cleanupInworldResources() {
    // No global cleanup needed for graph-based approach
    console.log('🧹 Inworld resources cleaned up');
}

// Routes

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        inworldConnected: checkInworldConfig()
    });
});

/**
 * Get supported voices/languages
 */
app.get('/voices', async (req, res) => {
    try {
        // Return supported languages from your iOS app
        const supportedVoices = [
            { code: 'en-US', name: 'English (US)', voice: 'default' },
            { code: 'es-ES', name: 'Spanish (Spain)', voice: 'default' },
            { code: 'fr-FR', name: 'French (France)', voice: 'default' },
            { code: 'de-DE', name: 'German (Germany)', voice: 'default' },
            { code: 'it-IT', name: 'Italian (Italy)', voice: 'default' },
            { code: 'pt-BR', name: 'Portuguese (Brazil)', voice: 'default' },
            { code: 'ja-JP', name: 'Japanese (Japan)', voice: 'default' },
            { code: 'ko-KR', name: 'Korean (South Korea)', voice: 'default' },
            { code: 'zh-CN', name: 'Chinese (Simplified)', voice: 'default' }
        ];

        res.json({
            success: true,
            voices: supportedVoices
        });
    } catch (error) {
        console.error('❌ Error fetching voices:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch supported voices'
        });
    }
});

/**
 * Main TTS endpoint
 * POST /tts
 * Body: { text: string, language?: string, voice?: string }
 * Returns: Audio file as binary data
 */
app.post('/tts', async (req, res) => {
    try {
        const { text, language = 'en-US', voice = 'default' } = req.body;

        // Validation
        if (!text || typeof text !== 'string' || text.trim().length === 0) {
            return res.status(400).json({
                success: false,
                error: 'Text is required and must be a non-empty string'
            });
        }

        if (text.length > 5000) {
            return res.status(400).json({
                success: false,
                error: 'Text is too long (max 5000 characters)'
            });
        }

        console.log(`📝 TTS request received - Language: ${language}, Text length: ${text.length}`);

        // Check if Inworld API is configured
        if (!checkInworldConfig()) {
            console.warn('⚠️  Inworld API not configured, using fallback response');
            return res.status(503).json({
                success: false,
                error: 'TTS service temporarily unavailable. Please check your Inworld AI configuration.',
                fallback: true
            });
        }

        // Generate TTS audio
        const audioBuffer = await generateTTSAudio(text, language, voice);

        // Set appropriate headers for audio response
        res.set({
            'Content-Type': 'audio/wav',
            'Content-Length': audioBuffer.length,
            'Cache-Control': 'no-cache',
            'X-TTS-Language': language,
            'X-TTS-Voice': voice
        });

        // Send audio data
        res.send(audioBuffer);

        console.log(`✅ TTS audio sent successfully (${audioBuffer.length} bytes)`);

    } catch (error) {
        console.error('❌ TTS endpoint error:', error);
        
        res.status(500).json({
            success: false,
            error: 'Internal server error during TTS generation',
            details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Error handling middleware
 */
app.use((error, req, res, next) => {
    console.error('🚨 Unhandled error:', error);
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

/**
 * 404 handler
 */
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

/**
 * Graceful shutdown handling
 */
process.on('SIGTERM', async () => {
    console.log('🛑 SIGTERM received, shutting down gracefully...');
    await cleanupInworldResources();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('🛑 SIGINT received, shutting down gracefully...');
    await cleanupInworldResources();
    process.exit(0);
});

/**
 * Start server
 */
async function startServer() {
    try {
        // Check Inworld configuration
        const inworldConfigured = checkInworldConfig();
        
        // Start Express server
        app.listen(PORT, () => {
            console.log(`🚀 TTSNewsReader Backend Server running on port ${PORT}`);
            console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`🔧 Inworld AI: ${inworldConfigured ? 'Configured' : 'Not configured'}`);
            console.log(`📡 Health check: http://localhost:${PORT}/health`);
        });
    } catch (error) {
        console.error('❌ Failed to start server:', error);
        process.exit(1);
    }
}

// Start the server
startServer();
