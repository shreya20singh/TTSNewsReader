/**
 * TTSNewsReader Backend Server
 * Integrates with Inworld AI for Text-to-Speech functionality
 * Handles news fetching and TTS conversion in a unified backend
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const axios = require('axios');
const { NodeFactory, GraphBuilder, ComponentFactory } = require('@inworld/runtime/graph');
const { TTSOutputStreamIterator } = require('@inworld/runtime/common');

const app = express();
const PORT = process.env.PORT || 3000;

// Inworld AI configuration
const INWORLD_API_BASE = 'https://api.inworld.ai';
const DEFAULT_MODEL = 'inworld-tts-1-max';
const DEFAULT_VOICE_ID = 'Ronald';
const DEFAULT_WORKSPACE_ID = 'default-jv9rith_zenenocmvv4daq';

// News API configuration
const NEWS_API_KEY = process.env.NEWS_API_KEY;
const NEWS_API_BASE = 'https://newsapi.org/v2';

// Inworld SDK instance
let inworldClient = null;

// Middleware
app.use(helmet());
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
});

// Language to voice mapping using actual Inworld voice IDs from documentation
const LANGUAGE_VOICE_MAP = {
    'en-US': 'Hades',      // English (US) - Female voice
    'en-GB': 'Ronald',        // English (UK) - Male voice
    'es-ES': 'Ronald',      // Spanish - Use Ashley for now
    'fr-FR': 'Ronald',      // French - Use Ashley for now
    'de-DE': 'Ronald',      // German - Use Ashley for now
    'it-IT': 'Ronald',      // Italian - Use Ashley for now
    'pt-BR': 'Ronald',      // Portuguese (Brazil) - Use Ashley for now
    'ja-JP': 'Ronald',      // Japanese - Use Ashley for now
    'ko-KR': 'Ashley',      // Korean - Use Ashley for now
    'zh-CN': 'Ashley',      // Chinese (Mandarin) - Use Ashley for now
    'ru-RU': 'Dennis',      // Russian - Use Ashley for now
    'ar-SA': 'Dennis',      // Arabic - Use Ashley for now
    'hi-IN': 'Hades'       // Hindi - Use Ashley for now
};

// Language mapping for translation
const LANGUAGE_NAMES = {
    'en-US': 'English',
    'en-GB': 'English',
    'es-ES': 'Spanish',
    'fr-FR': 'French',
    'de-DE': 'German',
    'it-IT': 'Italian',
    'pt-BR': 'Portuguese',
    'ja-JP': 'Japanese',
    'ko-KR': 'Korean',
    'zh-CN': 'Chinese',
    'ru-RU': 'Russian',
    'ar-SA': 'Arabic',
    'hi-IN': 'Hindi'
};

// LLM configuration for translation
const LLM_CONFIG = {
    provider: 'inworld',
    modelName: 'gemini-2.5-flash',
    max_new_tokens: 2500,
    max_prompt_length: 1000,
    repetition_penalty: 1,
    top_p: 1,
    temperature: 0.3, // Lower temperature for more consistent translations
    frequency_penalty: 0,
    presence_penalty: 0,
    stop_sequences: ['\n\n']
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
 * Check News API configuration
 */
function checkNewsApiConfig() {
    const hasApiKey = NEWS_API_KEY && !NEWS_API_KEY.includes('your_');
    
    if (hasApiKey) {
        console.log('✅ News API key configured');
        return true;
    } else {
        console.warn('⚠️  NEWS_API_KEY not found or not configured properly');
        return false;
    }
}

/**
 * Fetch news articles from News API
 */
async function fetchNewsArticles(category = 'general', country = 'us', pageSize = 20) {
    try {
        if (!checkNewsApiConfig()) {
            throw new Error('News API not configured');
        }

        const response = await axios.get(`${NEWS_API_BASE}/top-headlines`, {
            params: {
                country,
                category,
                pageSize,
                apiKey: NEWS_API_KEY
            },
            timeout: 10000
        });

        if (response.data.status === 'ok') {
            console.log(`📰 Fetched ${response.data.articles.length} news articles`);
            return response.data.articles;
        } else {
            throw new Error(`News API error: ${response.data.message}`);
        }
    } catch (error) {
        console.error('❌ Failed to fetch news:', error.message);
        throw error;
    }
}

/**
 * Check if language requires translation (non-English)
 */
function requiresTranslation(language) {
    return !language.startsWith('en-');
}

// Translation is now handled directly in the generateTTSAudio function using the two-graph approach

/**
 * Convert Float32Array audio data to WAV buffer
 * @param {number[]} audioData - Array of audio samples
 * @param {number} sampleRate - Sample rate (default 22050)
 * @returns {Buffer} WAV audio buffer
 */
function convertAudioDataToWAV(audioData, sampleRate = 22050) {
    const numChannels = 1; // Mono
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * bitsPerSample / 8;
    const blockAlign = numChannels * bitsPerSample / 8;
    const dataSize = audioData.length * 2; // 16-bit samples
    const chunkSize = 36 + dataSize;

    // Create WAV header
    const header = Buffer.alloc(44);
    let offset = 0;

    // RIFF header
    header.write('RIFF', offset); offset += 4;
    header.writeUInt32LE(chunkSize, offset); offset += 4;
    header.write('WAVE', offset); offset += 4;

    // fmt chunk
    header.write('fmt ', offset); offset += 4;
    header.writeUInt32LE(16, offset); offset += 4; // fmt chunk size
    header.writeUInt16LE(1, offset); offset += 2; // audio format (PCM)
    header.writeUInt16LE(numChannels, offset); offset += 2;
    header.writeUInt32LE(sampleRate, offset); offset += 4;
    header.writeUInt32LE(byteRate, offset); offset += 4;
    header.writeUInt16LE(blockAlign, offset); offset += 2;
    header.writeUInt16LE(bitsPerSample, offset); offset += 2;

    // data chunk
    header.write('data', offset); offset += 4;
    header.writeUInt32LE(dataSize, offset);

    // Convert Float32Array to 16-bit PCM
    const pcmData = Buffer.alloc(dataSize);
    for (let i = 0; i < audioData.length; i++) {
        // Convert float (-1 to 1) to 16-bit signed integer
        const sample = Math.max(-1, Math.min(1, audioData[i]));
        const intSample = Math.floor(sample * 32767);
        pcmData.writeInt16LE(intSample, i * 2);
    }

    return Buffer.concat([header, pcmData]);
}

/**
 * Generate TTS audio using Inworld graph executor structure (node_tts pattern)
 * @param {string} text - Text to convert to speech
 * @param {string} language - Language code (e.g., 'en-US')
 * @param {string} voice - Voice identifier
 * @returns {Buffer} Audio data as buffer
 */
async function generateTTSAudio(text, language = 'en-US', voice = 'default') {
    try {
        console.log(`🎤 Generating TTS using graph executor for text: "${text.substring(0, 50)}..."`);
        console.log(`🌍 Language: ${language}, Voice: ${voice}`);

        if (!process.env.INWORLD_API_KEY) {
            console.warn('⚠️  Inworld API key not configured, using fallback');
            return generateTestAudio(text);
        }

        const voiceName = getVoiceForLanguage(language, voice);
        let executor;
        let graphInput = text;
        
        try {
            // Check if translation is needed based on language
            if (requiresTranslation(language)) {
                const targetLanguageName = LANGUAGE_NAMES[language] || language;
                console.log(`🔄 Translation enabled for ${targetLanguageName}. Original text:`, text.substring(0, 50) + '...');
                
                // Step 1: Create a separate graph just for translation
                const translationLLMNode = NodeFactory.createRemoteLLMChatNode({
                    id: `translation_llm_${Date.now()}`,
                    llmConfig: {
                        provider: LLM_CONFIG.provider,
                        modelName: LLM_CONFIG.modelName,
                        apiKey: process.env.INWORLD_API_KEY,
                        stream: false,
                        textGenerationConfig: LLM_CONFIG
                    }
                });
                
                const translationInputNode = NodeFactory.createProxyNode({
                    id: `translation_input_${Date.now()}`,
                    reportToClient: false,
                });
                
                const translationOutputNode = NodeFactory.createProxyNode({
                    id: `translation_output_${Date.now()}`,
                    reportToClient: false,
                });
                
                // Build a simple translation graph
                const translationExecutor = new GraphBuilder(`translation_graph_${Date.now()}`)
                    .addNode(translationInputNode)
                    .addNode(translationLLMNode)
                    .addNode(translationOutputNode)
                    .addEdge(translationInputNode, translationLLMNode)
                    .addEdge(translationLLMNode, translationOutputNode)
                    .setStartNode(translationInputNode)
                    .setEndNode(translationOutputNode)
                    .getExecutor();
                
                // Create translation prompt based on target language
                const systemMessage = {
                    role: 'system',
                    content: `You are a translation assistant. Translate the given text to ${targetLanguageName}. Only respond with the translated text, nothing else.`,
                };
                
                const userMessage = {
                    role: 'user',
                    content: text,
                };
                
                const translationPrompt = {
                    messages: [systemMessage, userMessage],
                };
                
                // Execute translation graph with translation prompt
                console.log(`📤 Executing translation graph for ${text.length} characters...`);
                const translationStream = await translationExecutor.execute(translationPrompt, `translation_${Date.now()}`);
                
                // Get translation result
                const translationResult = await translationStream.next();
                let translatedText = '';
                
                if (translationResult.type === 'CONTENT') {
                    // Handle non-streaming LLM response
                    const response = translationResult.data;
                    translatedText = response.content;
                    console.log(`📥 Translation Result (non-streaming): ${translatedText.substring(0, 50)}...`);
                } else if (translationResult.type === 'CONTENT_STREAM') {
                    // Handle streaming LLM response
                    const streamIterator = translationResult.data;
                    
                    // Collect all chunks from the stream
                    while (true) {
                        const chunk = await streamIterator.next();
                        if (chunk.done) {
                            break;
                        }
                        
                        if (chunk.text) {
                            translatedText += chunk.text;
                        }
                    }
                    
                    console.log(`📡 Translation Result (streaming): ${translatedText.substring(0, 50)}...`);
                }
                
                // Clean up translation resources
                translationExecutor.closeExecution(translationStream);
                translationExecutor.stopExecutor();
                translationExecutor.cleanupAllExecutions();
                translationExecutor.destroy();
                
                if (!translatedText || translatedText.trim().length === 0) {
                    console.warn('⚠️ Translation returned empty result, using original text');
                } else {
                    // Use the translated text as input to the TTS graph
                    graphInput = translatedText;
                }
            } else {
                // Translation is disabled - use original text
                console.log('🎵 No translation needed. Using original text for TTS.');
            }
            
            // Step 2: Now create a TTS graph with the translated text
            console.log(`📤 Creating TTS graph executor (Voice: ${voiceName})...`);
            
            // Create TTS component following node_tts template pattern
            const ttsComponent = ComponentFactory.createRemoteTTSComponent({
                id: `tts_component_${Date.now()}`,
                apiKey: process.env.INWORLD_API_KEY,
                synthesisConfig: {
                    type: 'inworld',
                    config: {
                        modelId: DEFAULT_MODEL,
                        postprocessing: {
                            sampleRate: 22050,
                        },
                        inference: {
                            pitch: 0,
                            speakingRate: 1,
                            temperature: 0.8,
                        },
                    },
                },
            });

            // Create TTS node that will convert text to speech
            const ttsNode = NodeFactory.createRemoteTTSNode({
                id: `tts_node_${Date.now()}`,
                ttsComponentId: ttsComponent.id,
                voice: {
                    speakerId: voiceName,
                },
            });

            // Create input and output proxy nodes for the graph
            const inputProxyNode = NodeFactory.createProxyNode({
                id: `input_${Date.now()}`,
                reportToClient: false,
            });

            const outputProxyNode = NodeFactory.createProxyNode({
                id: `output_${Date.now()}`,
                reportToClient: false,
            });

            // Build the graph: input -> TTS -> output
            executor = new GraphBuilder(`tts_graph_${Date.now()}`)
                .addComponent(ttsComponent)        // Add TTS component to the graph
                .addNode(inputProxyNode)           // Add input node
                .addNode(ttsNode)                  // Add TTS node
                .addNode(outputProxyNode)          // Add output node
                .addEdge(inputProxyNode, ttsNode)  // Connect input to TTS
                .addEdge(ttsNode, outputProxyNode) // Connect TTS to output
                .setStartNode(inputProxyNode)      // Set input as start node
                .setEndNode(outputProxyNode)       // Set output as end node
                .getExecutor();                    // Get the executor

            console.log(`🎵 Executing TTS graph for ${graphInput.length} characters...`);

            // Execute the graph with the text input
            const outputStream = await executor.execute(graphInput, `execution_${Date.now()}`);
            
            // Get TTS stream from the output
            const ttsResult = await outputStream.next();
            const ttsStream = ttsResult.data;

            let allAudioData = [];
            let resultCount = 0;
            let initialText = '';

            // Process audio chunks from the TTS stream
            let chunk = await ttsStream.next();
            while (!chunk.done) {
                if (chunk.text) {
                    initialText += chunk.text;
                }
                if (chunk.audio && chunk.audio.data) {
                    allAudioData = allAudioData.concat(Array.from(chunk.audio.data));
                }
                resultCount++;
                chunk = await ttsStream.next();
            }

            console.log(`✅ TTS graph completed - Result count: ${resultCount}`);
            console.log(`📊 Generated audio for text: "${initialText.substring(0, 50)}..."`);

            // Clean up graph resources
            executor.closeExecution(outputStream);
            executor.stopExecutor();
            executor.cleanupAllExecutions();
            executor.destroy();

            if (allAudioData.length > 0) {
                // Convert Float32Array audio data to WAV buffer
                const audioBuffer = convertAudioDataToWAV(allAudioData, 22050);
                console.log(`✅ TTS graph executor completed successfully (${audioBuffer.length} bytes)`);
                
                // Save audio to file for debugging/reference (optional)
                const outputDir = path.join(__dirname, 'data-output', 'tts_samples');
                if (!fs.existsSync(outputDir)) {
                    fs.mkdirSync(outputDir, { recursive: true });
                }
                const outputFile = path.join(outputDir, `tts_output_${Date.now()}.wav`);
                fs.writeFileSync(outputFile, audioBuffer);
                console.log(`💾 Audio sample saved to ${outputFile}`);
                
                return audioBuffer;
            } else {
                console.warn('⚠️  TTS graph returned empty audio data');
                throw new Error('No audio content from TTS graph');
            }

        } catch (graphError) {
            console.warn('⚠️  TTS graph executor failed:', graphError.message);
            
            // Fallback to REST API if graph executor fails
            try {
                console.log('🔄 Trying REST API fallback...');
                const response = await axios.post(
                    `${INWORLD_API_BASE}/tts/v1/voice`,
                    {
                        text: graphInput,
                        voiceId: voiceName,
                        modelId: DEFAULT_MODEL
                    },
                    {
                        headers: {
                            'Authorization': `Basic ${process.env.INWORLD_API_KEY}`,
                            'Content-Type': 'application/json'
                        },
                        timeout: 30000
                    }
                );
                
                if (response.data && response.data.audioContent) {
                    const audioBuffer = Buffer.from(response.data.audioContent, 'base64');
                    console.log(`✅ REST API fallback succeeded (${audioBuffer.length} bytes)`);
                    return audioBuffer;
                }
            } catch (restError) {
                console.warn('⚠️  REST API fallback also failed:', restError.message);
            }
            
            console.warn('🧪 Using test audio fallback...');
            return generateTestAudio(graphInput);
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
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        services: {
            inworld: checkInworldConfig() ? 'configured' : 'not_configured',
            newsApi: checkNewsApiConfig() ? 'configured' : 'not_configured'
        }
    });
});

/**
 * Unified News + TTS endpoint
 * GET /news-audio?category=general&language=en-US&voice=default
 * Returns: JSON with news articles and audio URLs
 */
app.get('/news-audio', async (req, res) => {
    try {
        const { 
            category = 'general', 
            country = 'us', 
            language = 'en-US', 
            voice = 'default',
            pageSize = 1 
        } = req.query;

        console.log(`📰 News+TTS request: ${category}/${country}, ${language}/${voice}`);

        // Fetch news articles
        const articles = await fetchNewsArticles(category, country, parseInt(pageSize));
        
        if (!articles || articles.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'No news articles found',
                articles: []
            });
        }

        // Process articles and generate TTS for each
        const processedArticles = await Promise.all(
            articles.map(async (article, index) => {
                try {
                    // Create article text for TTS (title + description)
                    let articleText = `${article.title}. ${article.description || ''}`;
                    
                    // Translate text if target language is not English
                    if (requiresTranslation(language)) {
                        console.log(`🌐 Article ${index + 1}: Translating to ${LANGUAGE_NAMES[language] || language}`);
                        articleText = await translateTextWithLLM(articleText, language);
                    }
                    
                    // Generate TTS audio for this article (translated or original)
                    const audioBuffer = await generateTTSAudio(articleText, language, voice);
                    
                    // Create a unique audio ID for this article
                    const audioId = `article_${Date.now()}_${index}`;
                    
                    // Store audio in memory (in production, use proper storage)
                    global.audioCache = global.audioCache || new Map();
                    global.audioCache.set(audioId, audioBuffer);
                    
                    return {
                        id: article.url || `article_${index}`,
                        title: article.title,
                        description: article.description,
                        url: article.url,
                        urlToImage: article.urlToImage,
                        publishedAt: article.publishedAt,
                        source: article.source,
                        audioId: audioId,
                        audioUrl: `/audio/${audioId}`,
                        audioLength: audioBuffer.length,
                        textLength: articleText.length
                    };
                } catch (error) {
                    console.error(`❌ Failed to process article ${index}:`, error.message);
                    return {
                        id: article.url || `article_${index}`,
                        title: article.title,
                        description: article.description,
                        url: article.url,
                        urlToImage: article.urlToImage,
                        publishedAt: article.publishedAt,
                        source: article.source,
                        audioId: null,
                        audioUrl: null,
                        error: 'TTS generation failed'
                    };
                }
            })
        );

        console.log(`✅ Processed ${processedArticles.length} articles with TTS`);

        res.json({
            success: true,
            articles: processedArticles,
            metadata: {
                category,
                country,
                language,
                voice,
                totalArticles: processedArticles.length,
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        console.error('❌ News+TTS endpoint error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch news and generate audio',
            details: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Audio streaming endpoint
 * GET /audio/:audioId
 * Returns: Audio file as binary stream
 */
app.get('/audio/:audioId', (req, res) => {
    try {
        const { audioId } = req.params;
        
        // Retrieve audio from cache
        const audioBuffer = global.audioCache?.get(audioId);
        
        if (!audioBuffer) {
            return res.status(404).json({
                success: false,
                error: 'Audio not found or expired'
            });
        }

        // Set appropriate headers for audio streaming
        res.set({
            'Content-Type': 'audio/wav',
            'Content-Length': audioBuffer.length,
            'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
            'Accept-Ranges': 'bytes'
        });

        // Stream the audio
        res.send(audioBuffer);
        
        console.log(`🎵 Audio streamed: ${audioId} (${audioBuffer.length} bytes)`);
        
    } catch (error) {
        console.error('❌ Audio streaming error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to stream audio'
        });
    }
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
        console.log('🚀 Starting TTSNewsReader Backend Server...');
        
        // Check Inworld AI configuration
        const inworldConfigured = checkInworldConfig();
        
        // Check News API configuration
        const newsApiConfigured = checkNewsApiConfig();
        
        // Start Express server
        app.listen(PORT, () => {
            console.log(`🚀 TTSNewsReader Backend Server running on port ${PORT}`);
            console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`🔧 Inworld AI: ${inworldConfigured ? 'Configured' : 'Not configured'}`);
            console.log(`📰 News API: ${newsApiConfigured ? 'Configured' : 'Not configured'}`);
            console.log(`📡 Health check: http://localhost:${PORT}/health`);
            console.log(`🎵 Unified endpoint: http://localhost:${PORT}/news-audio`);
            
            if (!inworldConfigured) {
                console.warn('⚠️  Warning: Inworld AI not properly configured. TTS will use fallback audio.');
            }
            
            if (!newsApiConfigured) {
                console.warn('⚠️  Warning: News API not configured. News fetching will fail.');
            }
        });
    } catch (error) {
        console.error('❌ Failed to start server:', error);
        process.exit(1);
    }
}

// Start the server
startServer();
