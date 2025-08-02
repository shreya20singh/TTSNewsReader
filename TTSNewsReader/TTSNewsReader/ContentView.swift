//
//  ContentView.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NewsReaderViewModel()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.newsService.articles.isEmpty && !viewModel.newsService.isLoading {
                // Empty state
                EmptyStateView(onRefresh: {
                    Task {
                        await viewModel.refreshNews()
                    }
                })
            } else {
                // Main content
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        currentLanguage: viewModel.metrics.selectedLanguage,
                        onLanguageTap: {
                            viewModel.showingLanguageSelector = true
                        },
                        onMetricsTap: {
                            viewModel.toggleMetricsView()
                        },
                        onDebugTap: {
                            Task {
                                await viewModel.debugFetchNews()
                            }
                        }
                    )
                    
                    // News content
                    if let article = viewModel.currentArticle {
                        NewsArticleView(
                            article: article,
                            isPlaying: viewModel.ttsService.isPlaying,
                            isLoading: viewModel.ttsService.isLoading,
                            currentIndex: viewModel.currentArticleIndex,
                            totalCount: viewModel.newsService.articles.count,
                            onPlay: {
                                Task {
                                    await viewModel.playCurrentArticle()
                                }
                            },
                            onPause: {
                                viewModel.pauseAudio()
                            },
                            onRepeat: {
                                Task {
                                    await viewModel.repeatCurrentArticle()
                                }
                            },
                            onSkip: {
                                viewModel.nextArticle()
                            },
                            onMoreInfo: {
                                Task {
                                    await viewModel.loadMoreOnThis()
                                }
                            },
                            onPrevious: {
                                viewModel.previousArticle()
                            },
                            hasPrevious: viewModel.hasPreviousArticle,
                            hasNext: viewModel.hasNextArticle
                        )
                    } else if viewModel.newsService.isLoading {
                        LoadingView()
                    }
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingLanguageSelector) {
            LanguageSelectorView(
                currentLanguage: viewModel.metrics.selectedLanguage,
                onLanguageSelected: { language in
                    viewModel.changeLanguage(to: language)
                }
            )
        }
        .sheet(isPresented: $viewModel.showingMetrics) {
            MetricsView(metrics: viewModel.metrics) {
                viewModel.resetMetrics()
            }
        }
        .sheet(isPresented: $viewModel.showingExtendedContent) {
            ExtendedContentView(
                content: viewModel.extendedContent,
                isLoading: viewModel.isLoadingExtendedContent,
                isPlaying: viewModel.ttsService.isPlaying,
                onPlayPause: {
                    if viewModel.ttsService.isPlaying {
                        viewModel.pauseAudio()
                    } else {
                        viewModel.resumeAudio()
                    }
                },
                onClose: {
                    viewModel.showingExtendedContent = false
                    viewModel.stopAudio()
                }
            )
        }
        .task {
            // Auto-play first article when loaded
            if let _ = viewModel.currentArticle {
                await viewModel.playCurrentArticle()
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    let currentLanguage: TTSLanguage
    let onLanguageTap: () -> Void
    let onMetricsTap: () -> Void
    let onDebugTap: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice News Reader")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Personalized TTS Experience")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Debug button (only show if onDebugTap is provided)
                if let onDebugTap = onDebugTap {
                    Button(action: onDebugTap) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Language selector button
                Button(action: onLanguageTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(currentLanguage.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                }
                
                // Metrics button
                Button(action: onMetricsTap) {
                    Image(systemName: "chart.bar")
                        .padding(8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - News Article View
struct NewsArticleView: View {
    let article: NewsArticle
    let isPlaying: Bool
    let isLoading: Bool
    let currentIndex: Int
    let totalCount: Int
    let onPlay: () -> Void
    let onPause: () -> Void
    let onRepeat: () -> Void
    let onSkip: () -> Void
    let onMoreInfo: () -> Void
    let onPrevious: () -> Void
    let hasPrevious: Bool
    let hasNext: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress indicator
                ProgressIndicator(current: currentIndex + 1, total: totalCount)
                
                // Article content
                VStack(spacing: 16) {
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(article.displayDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal)
                    
                    HStack {
                        Text(article.source.name)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        
                        Spacer()
                        
                        Text(formatDate(article.publishedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Audio controls
                AudioControlsView(
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    onPlay: onPlay,
                    onPause: onPause,
                    onRepeat: onRepeat
                )
                
                // Action buttons
                ActionButtonsView(
                    onSkip: onSkip,
                    onMoreInfo: onMoreInfo,
                    onPrevious: onPrevious,
                    hasPrevious: hasPrevious,
                    hasNext: hasNext
                )
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Progress Indicator
struct ProgressIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Article \(current) of \(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            ProgressView(value: Double(current), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(.horizontal)
    }
}

// MARK: - Audio Controls View
struct AudioControlsView: View {
    let isPlaying: Bool
    let isLoading: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onRepeat: () -> Void
    
    var body: some View {
        HStack(spacing: 24) {
            // Repeat button
            Button(action: onRepeat) {
                Image(systemName: "repeat")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(50)
            }
            
            // Main play/pause button
            Button(action: isPlaying ? onPause : onPlay) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.blue)
                .cornerRadius(40)
            }
            .disabled(isLoading)
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 56, height: 56)
        }
        .padding()
    }
}

// MARK: - Action Buttons View
struct ActionButtonsView: View {
    let onSkip: () -> Void
    let onMoreInfo: () -> Void
    let onPrevious: () -> Void
    let hasPrevious: Bool
    let hasNext: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Previous button
                Button(action: onPrevious) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .foregroundColor(hasPrevious ? .blue : .gray)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(!hasPrevious)
                
                // Skip button
                Button(action: onSkip) {
                    HStack {
                        Text("Skip")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(hasNext ? .blue : .gray)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(!hasNext)
            }
            
            // More info button
            Button(action: onMoreInfo) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("More on This")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading news articles...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "newspaper")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No News Articles")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Tap refresh to load the latest news")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onRefresh) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
