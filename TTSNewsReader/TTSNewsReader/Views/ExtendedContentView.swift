//
//  ExtendedContentView.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import SwiftUI

struct ExtendedContentView: View {
    let content: String
    let isLoading: Bool
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading extended content...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        // Audio controls
                        HStack {
                            Button(action: onPlayPause) {
                                HStack(spacing: 8) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    Text(isPlaying ? "Pause" : "Play Extended Content")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom)
                        
                        // Content
                        Text(content)
                            .font(.body)
                            .lineSpacing(4)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Extended Content")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    onClose()
                }
            )
        }
    }
}

#Preview {
    ExtendedContentView(
        content: "This is a sample extended content that would be fetched from the news API or a content extraction service. It provides more detailed information about the news article.",
        isLoading: false,
        isPlaying: false,
        onPlayPause: {},
        onClose: {}
    )
}
