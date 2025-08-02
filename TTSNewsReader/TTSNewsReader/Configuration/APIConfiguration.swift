//
//  APIConfiguration.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation

// MARK: - API Configuration
struct APIConfiguration {
    // MARK: - News API Configuration
    static let newsAPIKey = "58ed64e02818412b9360de24071ee31a"
    static let newsAPIBaseURL = "https://newsapi.org/v2"
    
    // MARK: - Inworld AI TTS Configuration
    // Use Basic Authentication with your API key (Base64 encoded)
    // For Basic auth, use your actual API key from Inworld AI dashboard
    static let inworldAPIKey = "tg4SWdsTxawQ3ZeZBcaj4iV90sEIxpCI"
    static let inworldBaseURL = "https://api.inworld.ai/tts/v1"
    
    // MARK: - Default Settings
    static let defaultCountry = "us"
    static let defaultCategory = "general"
    static let defaultPageSize = 20
    static let defaultLanguage = "en"
    
    // MARK: - API Validation
    static var isNewsAPIConfigured: Bool {
        return !newsAPIKey.contains("YOUR_") && !newsAPIKey.isEmpty
    }
    
    static var isInworldAPIConfigured: Bool {
        return !inworldAPIKey.contains("YOUR_") && !inworldAPIKey.isEmpty
    }
    
    // MARK: - Environment Check
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

// MARK: - API Endpoints
extension APIConfiguration {
    enum NewsEndpoint {
        case topHeadlines
        case everything
        case sources
        
        var path: String {
            switch self {
            case .topHeadlines:
                return "/top-headlines"
            case .everything:
                return "/everything"
            case .sources:
                return "/sources"
            }
        }
        
        var fullURL: String {
            return newsAPIBaseURL + path
        }
    }
    
    enum InworldEndpoint {
        case generateSpeech
        case generateSpeechStream
        case voices
        
        var path: String {
            switch self {
            case .generateSpeech:
                return "/voice"
            case .generateSpeechStream:
                return "/voice:stream"
            case .voices:
                return "/voices"
            }
        }
        
        var fullURL: String {
            return inworldBaseURL + path
        }
    }
}

// MARK: - Network Configuration
extension APIConfiguration {
    static func createCustomURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        // Set custom timeout values
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // Create a custom session with certificate validation handling
        let session = URLSession(
            configuration: config,
            delegate: CustomURLSessionDelegate(),
            delegateQueue: nil
        )
        
        return session
    }
}

// MARK: - Custom URLSession Delegate for SSL Handling
class CustomURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Get the server trust from the challenge
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get the host from the challenge
        let host = challenge.protectionSpace.host
        
        // Allow specific trusted domains
        let trustedDomains = ["newsapi.org", "api.inworld.ai", "httpbin.org"]
        
        if trustedDomains.contains(where: { host.contains($0) }) {
            print("🔒 Allowing trusted domain: \(host)")
            
            // Create a credential with the server trust
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("⚠️ Unknown domain: \(host), using default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
