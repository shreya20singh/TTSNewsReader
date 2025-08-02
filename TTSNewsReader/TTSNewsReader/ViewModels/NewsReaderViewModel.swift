//
//  NewsReaderViewModel.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation
import Combine

// MARK: - Main View Model
@MainActor
class NewsReaderViewModel: ObservableObject {
    // Services
    @Published var newsService = NewsService()
    @Published var ttsService = TTSService()
    @Published var metrics = MetricsModel()
    
    // State
    @Published var currentArticleIndex = 0
    @Published var showingLanguageSelector = false
    @Published var showingMetrics = false
    @Published var showingExtendedContent = false
    @Published var extendedContent: String = ""
    @Published var isLoadingExtendedContent = false
    
    // Computed Properties
    var currentArticle: NewsArticle? {
        guard !newsService.articles.isEmpty,
              currentArticleIndex < newsService.articles.count else {
            return nil
        }
        return newsService.articles[currentArticleIndex]
    }
    
    var hasNextArticle: Bool {
        currentArticleIndex < newsService.articles.count - 1
    }
    
    var hasPreviousArticle: Bool {
        currentArticleIndex > 0
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        
        // Use a different approach for initial loading
        Task { 
            await loadInitialData()
        }
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Listen to language changes and update TTS accordingly
        metrics.$selectedLanguage
            .sink { [weak self] _ in
                // Language changed, could restart current playback with new language
                // For now, we'll just track the change
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func loadInitialData() async {
        print("🚀 loadInitialData() called")
        
        // First, test the API connection
        await newsService.testAPIConnection()
        
        // Check if News API is configured
        print("🔧 Checking API configuration...")
        print("🔧 isNewsAPIConfigured: \(APIConfiguration.isNewsAPIConfigured)")
        print("🔧 newsAPIKey: \(APIConfiguration.newsAPIKey.prefix(10))...")
        
        // ALWAYS try to fetch from API first, regardless of configuration check
        print("🔄 Attempting to fetch from API...")
        await newsService.fetchTopHeadlines()
        
        print("📊 After API call - articles count: \(newsService.articles.count)")
        print("📊 Error message: \(newsService.errorMessage ?? "none")")
        
        // Only fallback to sample data if API failed AND we have no articles
        if newsService.articles.isEmpty {
            print("⚠️ No articles from API, loading sample data as fallback")
            await newsService.loadSampleData()
            print("📊 After loading sample data - articles count: \(newsService.articles.count)")
        } else {
            print("✅ Successfully loaded \(newsService.articles.count) real articles from API")
        }
        
        print("🏁 loadInitialData() completed with \(newsService.articles.count) articles")
    }
    
    // MARK: - News Navigation
    func nextArticle() {
        guard hasNextArticle else { return }
        
        metrics.trackSkip()
        currentArticleIndex += 1
        metrics.trackNewArticle()
        
        HapticService.shared.playSkipFeedback()
        
        // Auto-play the new article
        Task {
            await playCurrentArticle()
        }
    }
    
    func previousArticle() {
        guard hasPreviousArticle else { return }
        
        currentArticleIndex -= 1
        metrics.trackNewArticle()
        
        HapticService.shared.playSkipFeedback()
        
        // Auto-play the previous article
        Task {
            await playCurrentArticle()
        }
    }
    
    // MARK: - Audio Controls
    func playCurrentArticle() async {
        guard let article = currentArticle else { return }
        
        let textToRead = "\(article.title). \(article.displayDescription)"
        await ttsService.generateAndPlaySpeech(text: textToRead, language: metrics.selectedLanguage)
        
        metrics.trackHeadlineListen()
        HapticService.shared.playPlayPauseFeedback()
    }
    
    func repeatCurrentArticle() async {
        metrics.trackRepeat()
        HapticService.shared.playRepeatFeedback()
        
        await ttsService.repeatCurrentAudio()
    }
    
    func pauseAudio() {
        ttsService.pauseAudio()
        HapticService.shared.playPlayPauseFeedback()
    }
    
    func resumeAudio() {
        ttsService.resumeAudio()
        HapticService.shared.playPlayPauseFeedback()
    }
    
    func stopAudio() {
        ttsService.stopAudio()
        HapticService.shared.playPlayPauseFeedback()
    }
    
    // MARK: - Extended Content
    func loadMoreOnThis() async {
        guard let article = currentArticle else { return }
        
        metrics.trackMoreOnThis()
        HapticService.shared.playMoreInfoFeedback()
        
        isLoadingExtendedContent = true
        showingExtendedContent = true
        
        if let content = await newsService.fetchExtendedContent(for: article) {
            extendedContent = content
            
            // Auto-play the extended content
            await ttsService.generateAndPlaySpeech(text: content, language: metrics.selectedLanguage)
        }
        
        isLoadingExtendedContent = false
    }
    
    // MARK: - Language Selection
    func changeLanguage(to language: TTSLanguage) {
        metrics.selectedLanguage = language
        showingLanguageSelector = false
        HapticService.shared.playLanguageChangeFeedback()
    }
    
    // MARK: - Refresh News
    func refreshNews() async {
        print("🔄 refreshNews() called")
        // Check if News API is configured
        if APIConfiguration.isNewsAPIConfigured {
            print("✅ API is configured, fetching fresh news...")
            await newsService.fetchTopHeadlines()
            
            print("📊 After refresh API call - articles count: \(newsService.articles.count)")
            print("📊 Error message: \(newsService.errorMessage ?? "none")")
            
            // If no articles were fetched (API error), fallback to sample data
            if newsService.articles.isEmpty && newsService.errorMessage != nil {
                print("⚠️ API failed during refresh, falling back to sample data: \(newsService.errorMessage ?? "")")
                await newsService.loadSampleData()
            }
        } else {
            // API key not configured, use sample data
            print("⚠️ NewsAPI key not configured, using sample data")
            await newsService.loadSampleData()
        }
        
        currentArticleIndex = 0
        
        if !newsService.articles.isEmpty {
            metrics.trackNewArticle()
        }
        
        print("🏁 refreshNews() completed with \(newsService.articles.count) articles")
    }
    
    // MARK: - Search News
    func searchNews(query: String) async {
        // Check if News API is configured
        if APIConfiguration.isNewsAPIConfigured {
            await newsService.searchNews(query: query)
            
            // If no articles were fetched (API error), show error
            if newsService.articles.isEmpty && newsService.errorMessage != nil {
                print("Search failed: \(newsService.errorMessage ?? "")")
                // Don't fallback to sample data for search, keep current articles
                return
            }
        } else {
            // API key not configured, can't search
            print("NewsAPI key not configured, cannot search")
            return
        }
        
        currentArticleIndex = 0
        
        if !newsService.articles.isEmpty {
            metrics.trackNewArticle()
        }
    }
    
    // MARK: - Metrics
    func toggleMetricsView() {
        showingMetrics.toggle()
        HapticService.shared.playSelection()
    }
    
    func resetMetrics() {
        metrics.resetAllMetrics()
        HapticService.shared.playWarning()
    }
    
    // MARK: - Debug Functions
    func debugFetchNews() async {
        print("🔧 DEBUG: Manually testing news fetch...")
        await newsService.forceTestFetch()
        print("🔧 DEBUG: Force test completed - articles count: \(newsService.articles.count)")
    }
}
