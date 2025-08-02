//
//  LanguageSelectorView.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import SwiftUI

struct LanguageSelectorView: View {
    let currentLanguage: TTSLanguage
    let onLanguageSelected: (TTSLanguage) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(TTSLanguage.allCases, id: \.rawValue) { language in
                        LanguageCard(
                            language: language,
                            isSelected: language == currentLanguage,
                            onTap: {
                                onLanguageSelected(language)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Language Card Component
struct LanguageCard: View {
    let language: TTSLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Flag or language icon
                Text(flagEmoji(for: language))
                    .font(.system(size: 40))
                
                Text(language.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(language.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func flagEmoji(for language: TTSLanguage) -> String {
        switch language {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        }
    }
}

#Preview {
    LanguageSelectorView(
        currentLanguage: .english,
        onLanguageSelected: { _ in }
    )
}
