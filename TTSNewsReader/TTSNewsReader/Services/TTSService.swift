//
//  TTSService.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - TTS Service using Inworld AI
@MainActor
class TTSService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentText: String = ""
    
    private var audioPlayer: AVAudioPlayer?
    // Backend server configuration
    private let backendBaseURL = "http://localhost:3000"
    
    // Audio session setup
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Generate and Play Speech
    func generateAndPlaySpeech(text: String, language: TTSLanguage = .english) async {
        guard !text.isEmpty else { return }
        
        currentText = text
        isLoading = true
        errorMessage = nil
        
        do {
            let audioData = try await generateSpeech(text: text, language: language)
            await playAudio(data: audioData)
        } catch {
            errorMessage = "TTS Error: \(error.localizedDescription)"
            isLoading = false
            // Fallback to system TTS if Inworld AI fails
            await playWithSystemTTS(text: text)
        }
    }
    
    // MARK: - Generate Speech from Backend Server
    private func generateSpeech(text: String, language: TTSLanguage) async throws -> Data {
        // Use the Node.js backend TTS endpoint
        guard let url = URL(string: "\(backendBaseURL)/tts") else {
            throw TTSError.invalidURL
        }
        
        // Prepare the request body for the backend API
        let requestBody: [String: Any] = [
            "text": text,
            "language": language.rawValue,
            "voice": "default"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // 30 second timeout for TTS generation
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw TTSError.invalidRequest
        }
        
        print("🎤 Sending TTS request to backend: \(text.prefix(50))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Backend TTS API Error: Status \(httpResponse.statusCode)")
            
            // Try to parse error response
            if let responseData = String(data: data, encoding: .utf8) {
                print("Response: \(responseData)")
                
                // Check if it's a JSON error response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    throw TTSError.backendError(error)
                }
            }
            
            throw TTSError.apiError(httpResponse.statusCode)
        }
        
        // The backend returns raw audio data (WAV format)
        guard !data.isEmpty else {
            print("❌ Empty audio data received from backend")
            throw TTSError.invalidResponse
        }
        
        print("✅ Received audio data from backend: \(data.count) bytes")
        return data
    }
    
    // MARK: - Backend Health Check
    func checkBackendHealth() async -> Bool {
        guard let url = URL(string: "\(backendBaseURL)/health") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                return status == "ok"
            }
            
            return false
        } catch {
            print("❌ Backend health check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Get Supported Voices from Backend
    func getSupportedVoices() async -> [TTSVoice] {
        guard let url = URL(string: "\(backendBaseURL)/voices") else {
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success,
               let voicesArray = json["voices"] as? [[String: Any]] {
                
                return voicesArray.compactMap { voiceDict in
                    guard let code = voiceDict["code"] as? String,
                          let name = voiceDict["name"] as? String,
                          let voice = voiceDict["voice"] as? String else {
                        return nil
                    }
                    return TTSVoice(code: code, name: name, voice: voice)
                }
            }
            
            return []
        } catch {
            print("❌ Failed to fetch supported voices: \(error)")
            return []
        }
    }
    
    // MARK: - Play Audio
    private func playAudio(data: Data) async {
        do {
            // Try to play actual audio data from Inworld AI
            if !data.isEmpty {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.delegate = self
                
                isPlaying = true
                isLoading = false
                audioPlayer?.play()
            } else {
                // Fallback to system TTS if no audio data
                await playWithSystemTTS(text: currentText)
            }
        } catch {
            // Fallback to system TTS if audio player fails
            print("Audio player error: \(error). Falling back to system TTS.")
            await playWithSystemTTS(text: currentText)
        }
    }
    
    // MARK: - System TTS Fallback
    private func playWithSystemTTS(text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        let synthesizer = AVSpeechSynthesizer()
        
        // Set up delegate to track playing state
        let delegate = TTSSynthesizerDelegate { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                self?.isLoading = false
            }
        }
        
        synthesizer.delegate = delegate
        
        isPlaying = true
        isLoading = false
        
        synthesizer.speak(utterance)
        
        // Keep the delegate alive
        await withUnsafeContinuation { continuation in
            delegate.completion = {
                continuation.resume()
            }
        }
    }
    
    // MARK: - Playback Controls
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func resumeAudio() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // MARK: - Repeat Current Audio
    func repeatCurrentAudio() async {
        guard !currentText.isEmpty else { return }
        await generateAndPlaySpeech(text: currentText)
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            errorMessage = "Audio decode error: \(error.localizedDescription)"
        }
    }
}

// MARK: - TTS Voice Model
struct TTSVoice {
    let code: String
    let name: String
    let voice: String
}

// MARK: - TTS Errors
enum TTSError: Error {
    case networkError
    case invalidResponse
    case audioPlaybackError
    case apiNotConfigured
    case invalidURL
    case invalidRequest
    case apiError(Int)
    case backendError(String)
    case backendUnavailable
    
    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from TTS service"
        case .audioPlaybackError:
            return "Audio playback error"
        case .apiNotConfigured:
            return "Inworld AI API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidRequest:
            return "Invalid API request"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .backendUnavailable:
            return "TTS backend service is unavailable"
        }
    }
}

// MARK: - AVSpeechSynthesizer Delegate Helper
class TTSSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var completion: (() -> Void)?
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion?()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion?()
    }
}
