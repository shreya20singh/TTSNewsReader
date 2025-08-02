//
//  NewsArticle.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation

// MARK: - News Article Model
struct NewsArticle: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let source: Source
    
    // For extended content ("More on This" feature)
    var fullContent: String?
    
    struct Source: Codable {
        let id: String?
        let name: String
    }
    
    // Computed property for display
    var displayDescription: String {
        return description ?? "No description available"
    }
}

// MARK: - News API Response Models
struct NewsAPIResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [NewsArticle]
}

// MARK: - Supported Languages for TTS
enum TTSLanguage: String, CaseIterable {
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case chinese = "zh-CN"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese"
        }
    }
}
