//
//  HapticService.swift
//  TTSNewsReader
//
//  Created by Shreya Singh on 8/2/25.
//

import UIKit

// MARK: - Haptic Feedback Service
class HapticService {
    static let shared = HapticService()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for better performance
        impactFeedback.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Feedback Types
    func playButtonTap() {
        impactFeedback.impactOccurred()
    }
    
    func playSelection() {
        selectionFeedback.selectionChanged()
    }
    
    func playSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func playWarning() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func playError() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Context-specific Feedback
    func playSkipFeedback() {
        playSelection()
    }
    
    func playRepeatFeedback() {
        playButtonTap()
    }
    
    func playMoreInfoFeedback() {
        playSuccess()
    }
    
    func playLanguageChangeFeedback() {
        playSelection()
    }
    
    func playPlayPauseFeedback() {
        playButtonTap()
    }
}
