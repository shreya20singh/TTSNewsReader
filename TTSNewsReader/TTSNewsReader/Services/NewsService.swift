//
//  NewsService.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import Foundation
import Combine

// MARK: - News Service
class NewsService: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = APIConfiguration.newsAPIBaseURL
    private let apiKey = APIConfiguration.newsAPIKey
    private var cancellables = Set<AnyCancellable>()
    
    // Use custom URLSession to handle SSL issues
    private lazy var urlSession: URLSession = {
        return APIConfiguration.createCustomURLSession()
    }()
    
    // MARK: - Fetch Top Headlines
    func fetchTopHeadlines(country: String = "us", category: String = "general") async {
        print("🔍 Starting fetchTopHeadlines - isNewsAPIConfigured: \(APIConfiguration.isNewsAPIConfigured)")
        print("🔍 API Key (first 10 chars): \(String(apiKey.prefix(10)))...")
        print("🔍 Base URL: \(baseURL)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let url = buildURL(endpoint: "top-headlines", country: country, category: category) else {
            print("❌ Failed to build URL")
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        print("🌐 Fetching news from: \(url)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                await MainActor.run {
                    errorMessage = "Invalid response"
                    isLoading = false
                }
                return
            }
            
            print("📊 HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                // Log response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ API Error Response: \(responseString)")
                }
                await MainActor.run {
                    errorMessage = "API Error: Status \(httpResponse.statusCode)"
                    isLoading = false
                }
                return
            }
            
            // Log the raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 Raw API Response (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            let newsResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
            print("✅ Successfully decoded \(newsResponse.articles.count) articles")
            print("📰 Article titles: \(newsResponse.articles.map { $0.title }.prefix(3))")
            
            await MainActor.run {
                self.articles = newsResponse.articles
                isLoading = false
            }
            
        } catch {
            print("❌ News fetch error: \(error)")
            if let decodingError = error as? DecodingError {
                print("🔍 Decoding error details: \(decodingError)")
            }
            await MainActor.run {
                errorMessage = "Failed to fetch news: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Fetch Everything (for search)
    func searchNews(query: String) async {
        isLoading = true
        errorMessage = nil
        
        guard let url = buildSearchURL(query: query) else {
            errorMessage = "Invalid search URL"
            isLoading = false
            return
        }
        
        print("Searching news with: \(url)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }
            
            print("Search HTTP Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                // Log response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Search API Error Response: \(responseString)")
                }
                errorMessage = "Search API Error: Status \(httpResponse.statusCode)"
                isLoading = false
                return
            }
            
            let newsResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
            print("Successfully found \(newsResponse.articles.count) articles for query: \(query)")
            self.articles = newsResponse.articles
            isLoading = false
            
        } catch {
            print("News search error: \(error)")
            errorMessage = "Failed to search news: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Fetch Extended Content
    func fetchExtendedContent(for article: NewsArticle) async -> String? {
        // In a real implementation, you might:
        // 1. Use a web scraping service
        // 2. Call a different API endpoint
        // 3. Use an AI service to summarize the full article
        
        // For now, we'll simulate this with a delay and return extended content
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return """
        Extended content for: \(article.title)
        
        \(article.displayDescription)
        
        This is simulated extended content that would normally be fetched from the full article URL. In a production app, you would implement web scraping or use a content extraction service to get the full article text.
        
        Key points from this story:
        • Main topic coverage
        • Background information
        • Related developments
        • Expert opinions
        • Future implications
        
        Source: \(article.source.name)
        Published: \(article.publishedAt)
        """
    }
    
    // MARK: - Helper Methods
    private func buildURL(endpoint: String, country: String, category: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "pageSize", value: "20")
        ]
        return components?.url
    }
    
    private func buildSearchURL(query: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/everything")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "language", value: "en")
        ]
        return components?.url
    }
    
    // MARK: - Sample Data (for testing without API key)
    // MARK: - Sample Data (for testing without API key)
    @MainActor
    func loadSampleData() {
        print("📝 Loading sample data...")
        articles = [
            NewsArticle(
                title: "Breaking: Apple Unveils Revolutionary AI-Powered iPhone 17",
                description: "Apple has announced groundbreaking artificial intelligence features in their latest iPhone 17, including real-time translation and advanced camera capabilities that adapt to user behavior.",
                url: "https://example.com/apple-iphone-17",
                urlToImage: nil,
                publishedAt: "2025-08-02T10:30:00Z",
                source: NewsArticle.Source(id: "tech-news", name: "TechCrunch")
            ),
            NewsArticle(
                title: "Climate Breakthrough: New Carbon Capture Technology Shows Promise",
                description: "Scientists at MIT have developed a revolutionary carbon capture technology that could remove millions of tons of CO2 from the atmosphere at a fraction of current costs.",
                url: "https://example.com/carbon-capture",
                urlToImage: nil,
                publishedAt: "2025-08-02T09:45:00Z",
                source: NewsArticle.Source(id: "science", name: "Nature Science")
            ),
            NewsArticle(
                title: "Global Markets Rally as Inflation Shows Signs of Cooling",
                description: "Stock markets worldwide surge as latest economic data suggests inflation is finally beginning to stabilize, leading to optimism about future interest rate policies.",
                url: "https://example.com/markets-rally",
                urlToImage: nil,
                publishedAt: "2025-08-02T08:15:00Z",
                source: NewsArticle.Source(id: "business", name: "Financial Times")
            ),
            NewsArticle(
                title: "SpaceX Successfully Launches Mars Mission with New Rocket Technology",
                description: "SpaceX has launched its most ambitious Mars mission yet, featuring advanced propulsion systems and carrying scientific equipment that could pave the way for human exploration.",
                url: "https://example.com/spacex-mars",
                urlToImage: nil,
                publishedAt: "2025-08-02T07:20:00Z",
                source: NewsArticle.Source(id: "space", name: "Space News")
            ),
            NewsArticle(
                title: "Medical Breakthrough: New Gene Therapy Shows Promise for Alzheimer's",
                description: "Researchers have successfully tested a new gene therapy approach that shows significant promise in treating early-stage Alzheimer's disease, offering hope to millions of patients.",
                url: "https://example.com/alzheimers-therapy",
                urlToImage: nil,
                publishedAt: "2025-08-02T06:30:00Z",
                source: NewsArticle.Source(id: "health", name: "Medical Journal")
            ),
            NewsArticle(
                title: "Electric Vehicle Sales Surpass Gas Cars for First Time in Major Market",
                description: "Norway becomes the first country where electric vehicle sales have permanently overtaken traditional gas-powered cars, marking a historic shift in automotive industry trends.",
                url: "https://example.com/ev-milestone",
                urlToImage: nil,
                publishedAt: "2025-08-02T05:45:00Z",
                source: NewsArticle.Source(id: "automotive", name: "Auto Week")
            )
        ]
        print("✅ Sample data loaded successfully: \(articles.count) articles")
    }
    
    // MARK: - Debug Test Function
    func testAPIConnection() async {
        print("🧪 Testing API connection...")
        
        // First, print URL info
        printTestURL()
        
        let testURL = "https://httpbin.org/get"
        
        do {
            let (data, _) = try await urlSession.data(from: URL(string: testURL)!)
            if let responseString = String(data: data, encoding: .utf8) {
                print("✅ Basic internet connection test passed")
                print("📝 Response preview: \(String(responseString.prefix(100)))")
            }
        } catch {
            print("❌ Basic internet connection test failed: \(error)")
            return
        }
        
        // Test NewsAPI
        guard let newsURL = buildURL(endpoint: "top-headlines", country: "us", category: "general") else {
            print("❌ Failed to build NewsAPI URL")
            return
        }
        
        print("🌐 Testing URL: \(newsURL)")
        
        do {
            let (data, response) = try await urlSession.data(from: newsURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ NewsAPI test connection - Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📝 NewsAPI test response (first 300 chars): \(String(responseString.prefix(300)))")
                }
            }
        } catch {
            print("❌ NewsAPI test failed: \(error)")
        }
    }
    
    // MARK: - Debug Functions
    func forceTestFetch() async {
        print("🧪 FORCE TEST FETCH - Starting manual test...")
        
        // Clear existing data first
        await MainActor.run {
            articles = []
            errorMessage = nil
            isLoading = true
        }
        
        // Test URL construction
        let testURL = buildURL(endpoint: "top-headlines", country: "us", category: "general")
        print("🔧 Built URL: \(testURL?.absoluteString ?? "nil")")
        
        guard let url = testURL else {
            print("❌ URL construction failed")
            await MainActor.run {
                errorMessage = "URL construction failed"
                isLoading = false
            }
            return
        }
        
        // Make the request
        print("🌐 Making request to: \(url)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            print("📦 Received data size: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                print("📋 Headers: \(httpResponse.allHeaderFields)")
            }
            
            // Try to decode
            let decoder = JSONDecoder()
            let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
            
            print("✅ Successfully decoded response")
            print("📊 Status: \(newsResponse.status)")
            print("📊 Total results: \(newsResponse.totalResults)")
            print("📊 Articles count: \(newsResponse.articles.count)")
            
            if newsResponse.articles.count > 0 {
                print("📰 First article title: \(newsResponse.articles[0].title)")
            }
            
            await MainActor.run {
                self.articles = newsResponse.articles
                self.isLoading = false
                print("✅ Articles successfully set in main actor: \(self.articles.count)")
            }
            
        } catch {
            print("❌ Force test fetch error: \(error)")
            if let decodingError = error as? DecodingError {
                print("🔍 Decoding error details: \(decodingError)")
            }
            await MainActor.run {
                errorMessage = "Force test failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - URL Testing
    func printTestURL() {
        let url = buildURL(endpoint: "top-headlines", country: "us", category: "general")
        print("🔗 Test URL: \(url?.absoluteString ?? "Failed to build URL")")
        
        // Also test the individual components
        print("🔧 Base URL: \(baseURL)")
        print("🔧 API Key: \(apiKey)")
        print("🔧 API Key length: \(apiKey.count)")
        print("🔧 API Key isEmpty: \(apiKey.isEmpty)")
    }
}
