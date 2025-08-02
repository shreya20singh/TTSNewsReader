//
//  MetricsView.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import SwiftUI

struct MetricsView: View {
    @ObservedObject var metrics: MetricsModel
    let onReset: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text("Usage Metrics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Track your news engagement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Main Metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(
                            title: "Headlines Listened",
                            value: "\(metrics.headlineListens)",
                            icon: "play.circle.fill",
                            color: .green
                        )
                        
                        MetricCard(
                            title: "Articles Skipped",
                            value: "\(metrics.skips)",
                            icon: "forward.fill",
                            color: .orange
                        )
                        
                        MetricCard(
                            title: "Repeats",
                            value: "\(metrics.repeats)",
                            icon: "repeat",
                            color: .blue
                        )
                        
                        MetricCard(
                            title: "More Info Requests",
                            value: "\(metrics.moreOnThisRequests)",
                            icon: "info.circle.fill",
                            color: .purple
                        )
                        
                        MetricCard(
                            title: "Total Articles",
                            value: "\(metrics.totalArticlesViewed)",
                            icon: "newspaper.fill",
                            color: .primary
                        )
                        
                        MetricCard(
                            title: "Language Changes",
                            value: "\(metrics.languageChanges)",
                            icon: "globe",
                            color: .cyan
                        )
                    }
                    
                    // Engagement Stats
                    VStack(spacing: 16) {
                        Text("Engagement Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            EngagementRow(
                                title: "Engagement Rate",
                                value: String(format: "%.1f%%", metrics.engagementRate * 100),
                                description: "Percentage of articles you engaged with"
                            )
                            
                            EngagementRow(
                                title: "Avg. Listens per Article",
                                value: String(format: "%.1f", metrics.averageListensPerArticle),
                                description: "Average times you listen to each article"
                            )
                            
                            EngagementRow(
                                title: "Current Language",
                                value: metrics.selectedLanguage.displayName,
                                description: "Currently selected TTS language"
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Reset Button
                    Button(action: onReset) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Metrics")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Engagement Row Component
struct EngagementRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    MetricsView(metrics: MetricsModel()) {
        // Reset action
    }
}
