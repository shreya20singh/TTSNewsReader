#!/usr/bin/env swift

import Foundation

// Test the exact same API call that the iOS app makes
let apiKey = "58ed64e02818412b9360de24071ee31a"
let baseURL = "https://newsapi.org/v2"

func buildURL(endpoint: String, country: String, category: String) -> URL? {
    var components = URLComponents(string: "\(baseURL)/\(endpoint)")
    components?.queryItems = [
        URLQueryItem(name: "apiKey", value: apiKey),
        URLQueryItem(name: "country", value: country),
        URLQueryItem(name: "category", value: category),
        URLQueryItem(name: "pageSize", value: "20")
    ]
    return components?.url
}

// Test URL construction
if let url = buildURL(endpoint: "top-headlines", country: "us", category: "general") {
    print("✅ URL built successfully: \(url.absoluteString)")
    
    // Test the actual network call
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("❌ Network error: \(error)")
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
        }
        
        if let data = data {
            print("📦 Data size: \(data.count) bytes")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📝 Response preview: \(String(jsonString.prefix(200)))")
            }
        }
        
        exit(0)
    }
    
    task.resume()
    
    // Keep the script running
    RunLoop.main.run()
} else {
    print("❌ Failed to build URL")
}
