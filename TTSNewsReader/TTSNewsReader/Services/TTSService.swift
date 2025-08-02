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
    private let inworldAPIKey = APIConfiguration.inworldAPIKey
    private let inworldBaseURL = APIConfiguration.inworldBaseURL
    
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
    
    // MARK: - Generate Speech from Inworld AI
    private func generateSpeech(text: String, language: TTSLanguage) async throws -> Data {
        // Check if API is configured
        guard APIConfiguration.isInworldAPIConfigured else {
            throw TTSError.apiNotConfigured
        }
        
        // Use the correct Inworld AI TTS endpoint
        guard let url = URL(string: "\(inworldBaseURL)/voice") else {
            throw TTSError.invalidURL
        }
        
        // Prepare the request body according to Inworld AI API documentation
        let requestBody: [String: Any] = [
            "text": text,
            "voiceId": getVoiceIdForLanguage(language),
            "modelId": "inworld-tts-1"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Use Basic Authentication as per Inworld AI documentation
        let base64Credentials = Data(inworldAPIKey.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw TTSError.invalidRequest
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Inworld AI API Error: Status \(httpResponse.statusCode)")
            if let responseData = String(data: data, encoding: .utf8) {
                print("Response: \(responseData)")
            }
            throw TTSError.apiError(httpResponse.statusCode)
        }
        
        // Parse the response to extract audio data according to Inworld AI format
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let audioBase64 = json["audioContent"] as? String,
               let audioData = Data(base64Encoded: audioBase64) {
                return audioData
            } else {
                print("Invalid response format from Inworld AI")
                throw TTSError.invalidResponse
            }
        } catch {
            print("Failed to parse Inworld AI response: \(error)")
            throw TTSError.invalidResponse
        }
    }
    
    // MARK: - Get Voice ID for Language
    private func getVoiceIdForLanguage(_ language: TTSLanguage) -> String {
        switch language {
        case .english:
            return "Hades" // You can customize voice IDs based on available voices
        case .spanish:
            return "Hades"
        case .french:
            return "Hades"
        case .german:
            return "Hades"
        case .italian:
            return "Hades"
        case .portuguese:
            return "Hades"
        case .japanese:
            return "Hades"
        case .korean:
            return "Hades"
        case .chinese:
            return "Hades"
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

// MARK: - TTS Errors
enum TTSError: Error {
    case networkError
    case invalidResponse
    case audioPlaybackError
    case apiNotConfigured
    case invalidURL
    case invalidRequest
    case apiError(Int)
    
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
