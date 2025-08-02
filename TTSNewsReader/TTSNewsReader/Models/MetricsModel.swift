//
//  MetricsModel.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation

// MARK: - Metrics Tracking Model
@MainActor
class MetricsModel: ObservableObject {
    @Published var headlineListens: Int = 0
    @Published var skips: Int = 0
    @Published var repeats: Int = 0
    @Published var moreOnThisRequests: Int = 0
    @Published var languageChanges: Int = 0
    
    // Track per-article metrics
    @Published var currentArticleListens: Int = 0
    @Published var totalArticlesViewed: Int = 0
    
    // User preferences
    @Published var selectedLanguage: TTSLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedTTSLanguage")
            languageChanges += 1
        }
    }
    
    init() {
        // Load saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedTTSLanguage"),
           let language = TTSLanguage(rawValue: savedLanguage) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .english
        }
    }
    
    // MARK: - Metric Tracking Methods
    func trackHeadlineListen() {
        headlineListens += 1
        currentArticleListens += 1
    }
    
    func trackSkip() {
        skips += 1
        resetCurrentArticleMetrics()
    }
    
    func trackRepeat() {
        repeats += 1
    }
    
    func trackMoreOnThis() {
        moreOnThisRequests += 1
    }
    
    func trackNewArticle() {
        totalArticlesViewed += 1
        resetCurrentArticleMetrics()
    }
    
    private func resetCurrentArticleMetrics() {
        currentArticleListens = 0
    }
    
    // MARK: - Computed Properties for Display
    var engagementRate: Double {
        guard totalArticlesViewed > 0 else { return 0.0 }
        let engagedActions = headlineListens + moreOnThisRequests
        return Double(engagedActions) / Double(totalArticlesViewed)
    }
    
    var averageListensPerArticle: Double {
        guard totalArticlesViewed > 0 else { return 0.0 }
        return Double(headlineListens) / Double(totalArticlesViewed)
    }
    
    // MARK: - Reset Methods
    func resetAllMetrics() {
        headlineListens = 0
        skips = 0
        repeats = 0
        moreOnThisRequests = 0
        languageChanges = 0
        currentArticleListens = 0
        totalArticlesViewed = 0
    }
}
