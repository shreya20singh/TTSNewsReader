/**
 * Test script for TTSNewsReader Backend API
 * This script tests all the backend endpoints to ensure they're working correctly
 */

const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:3000';

/**
 * Test the health endpoint
 */
async function testHealth() {
    console.log('🏥 Testing health endpoint...');
    
    try {
        const response = await fetch(`${BASE_URL}/health`);
        const data = await response.json();
        
        if (response.ok && data.status === 'ok') {
            console.log('✅ Health check passed');
            console.log(`   - Status: ${data.status}`);
            console.log(`   - Inworld Connected: ${data.inworldConnected}`);
            return true;
        } else {
            console.log('❌ Health check failed');
            return false;
        }
    } catch (error) {
        console.log('❌ Health check failed:', error.message);
        return false;
    }
}

/**
 * Test the voices endpoint
 */
async function testVoices() {
    console.log('🎤 Testing voices endpoint...');
    
    try {
        const response = await fetch(`${BASE_URL}/voices`);
        const data = await response.json();
        
        if (response.ok && data.success) {
            console.log('✅ Voices endpoint passed');
            console.log(`   - Found ${data.voices.length} supported voices`);
            data.voices.slice(0, 3).forEach(voice => {
                console.log(`   - ${voice.name} (${voice.code})`);
            });
            return true;
        } else {
            console.log('❌ Voices endpoint failed');
            return false;
        }
    } catch (error) {
        console.log('❌ Voices endpoint failed:', error.message);
        return false;
    }
}

/**
 * Test the TTS endpoint
 */
async function testTTS() {
    console.log('🗣️  Testing TTS endpoint...');
    
    const testText = "Hello, this is a test of the Text-to-Speech system for TTSNewsReader.";
    
    try {
        const response = await fetch(`${BASE_URL}/tts`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                text: testText,
                language: 'en-US',
                voice: 'default'
            })
        });
        
        if (response.ok) {
            const audioBuffer = await response.arrayBuffer();
            const audioData = Buffer.from(audioBuffer);
            
            console.log('✅ TTS endpoint passed');
            console.log(`   - Generated ${audioData.length} bytes of audio data`);
            console.log(`   - Content-Type: ${response.headers.get('content-type')}`);
            
            // Save test audio file
            const testAudioPath = path.join(__dirname, 'test-audio.wav');
            fs.writeFileSync(testAudioPath, audioData);
            console.log(`   - Test audio saved to: ${testAudioPath}`);
            
            return true;
        } else {
            const errorData = await response.json();
            console.log('❌ TTS endpoint failed');
            console.log(`   - Status: ${response.status}`);
            console.log(`   - Error: ${errorData.error}`);
            
            if (errorData.fallback) {
                console.log('   - This might be expected if Inworld AI is not configured');
            }
            
            return false;
        }
    } catch (error) {
        console.log('❌ TTS endpoint failed:', error.message);
        return false;
    }
}

/**
 * Test invalid requests
 */
async function testErrorHandling() {
    console.log('⚠️  Testing error handling...');
    
    try {
        // Test empty text
        const response1 = await fetch(`${BASE_URL}/tts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ text: '' })
        });
        
        if (response1.status === 400) {
            console.log('✅ Empty text validation passed');
        } else {
            console.log('❌ Empty text validation failed');
        }
        
        // Test missing text
        const response2 = await fetch(`${BASE_URL}/tts`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ language: 'en-US' })
        });
        
        if (response2.status === 400) {
            console.log('✅ Missing text validation passed');
        } else {
            console.log('❌ Missing text validation failed');
        }
        
        // Test 404 endpoint
        const response3 = await fetch(`${BASE_URL}/nonexistent`);
        if (response3.status === 404) {
            console.log('✅ 404 handling passed');
        } else {
            console.log('❌ 404 handling failed');
        }
        
        return true;
    } catch (error) {
        console.log('❌ Error handling test failed:', error.message);
        return false;
    }
}

/**
 * Main test runner
 */
async function runTests() {
    console.log('🧪 Running TTSNewsReader Backend API Tests\n');
    
    const results = {
        health: await testHealth(),
        voices: await testVoices(),
        tts: await testTTS(),
        errorHandling: await testErrorHandling()
    };
    
    console.log('\n📊 Test Results Summary:');
    console.log('========================');
    
    Object.entries(results).forEach(([test, passed]) => {
        const status = passed ? '✅ PASSED' : '❌ FAILED';
        console.log(`${test.padEnd(15)}: ${status}`);
    });
    
    const totalTests = Object.keys(results).length;
    const passedTests = Object.values(results).filter(Boolean).length;
    
    console.log(`\nOverall: ${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
        console.log('🎉 All tests passed! Backend is ready for iOS integration.');
    } else {
        console.log('⚠️  Some tests failed. Please check the backend configuration.');
    }
}

// Check if server is running
async function checkServer() {
    try {
        await fetch(`${BASE_URL}/health`);
        return true;
    } catch (error) {
        return false;
    }
}

// Main execution
async function main() {
    const serverRunning = await checkServer();
    
    if (!serverRunning) {
        console.log('❌ Backend server is not running!');
        console.log('Please start the server first:');
        console.log('   cd backend && npm run dev');
        console.log('   or run: ./start-backend.sh');
        process.exit(1);
    }
    
    await runTests();
}

main().catch(console.error);
