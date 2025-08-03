/**
 * TTSNewsReader Backend Server
 * Node.js Express server with Inworld AI TTS integration
 * Following the official Inworld AI Node.js TTS template
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const https = require('https');
const http = require('http');

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

// Global variables for Inworld API
const INWORLD_TTS_BASE_URL = 'https://api.inworld.ai/tts/v1';

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

        // Prepare the request body for Inworld TTS API
        const requestBody = JSON.stringify({
            text: text,
            voice: getInworldVoiceId(language),
            model: 'inworld-tts-1'
        });

        // Make HTTP request to Inworld TTS API
        const response = await makeInworldTTSRequest(requestBody);
        
        if (!response || !response.audioContent) {
            throw new Error('No audio data received from Inworld AI');
        }

        // Convert base64 audio to buffer
        const audioBuffer = Buffer.from(response.audioContent, 'base64');
        console.log(`✅ TTS audio generated successfully (${audioBuffer.length} bytes)`);
        return audioBuffer;
    } catch (error) {
        console.error('❌ TTS generation failed:', error);
        throw error;
    }
}

/**
 * Make HTTP request to Inworld TTS API
 * @param {string} requestBody - JSON request body
 * @returns {Object} Response data
 */
async function makeInworldTTSRequest(requestBody) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.inworld.ai',
            port: 443,
            path: '/tts/v1/voice',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(requestBody),
                'Authorization': `Basic ${Buffer.from(process.env.INWORLD_API_KEY).toString('base64')}`
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 200) {
                    try {
                        const response = JSON.parse(data);
                        resolve(response);
                    } catch (error) {
                        reject(new Error(`Failed to parse response: ${error.message}`));
                    }
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        req.write(requestBody);
        req.end();
    });
}

/**
 * Get Inworld voice ID for language
 * @param {string} language - Language code
 * @returns {string} Voice ID
 */
function getInworldVoiceId(language) {
    const voiceMap = {
        'en-US': 'Hades',
        'es-ES': 'Hades',
        'fr-FR': 'Hades',
        'de-DE': 'Hades',
        'it-IT': 'Hades',
        'pt-BR': 'Hades',
        'ja-JP': 'Hades',
        'ko-KR': 'Hades',
        'zh-CN': 'Hades'
    };
    
    return voiceMap[language] || 'Hades';
}

/**
 * Clean up Inworld resources
 */
async function cleanupInworldResources() {
    // No cleanup needed for REST API approach
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
