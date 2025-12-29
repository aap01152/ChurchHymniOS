//
//  PresentCurrentHymnButton.swift
//  ChurchHymn
//
//  Created by Claude on 28/12/2025.
//

import SwiftUI
import UIKit

/// Button that allows seamless switching to the currently viewed hymn during worship sessions
/// Appears in the green toolbar when worship is active and viewed hymn differs from presented hymn
struct PresentCurrentHymnButton: View {
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    let currentHymn: Hymn?
    
    @State private var isPresenting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0.0
    @State private var pulseOpacity: Double = 0.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        if shouldShowButton {
            UniformControlButton(
                icon: buttonIcon,
                text: buttonText,
                action: presentCurrentHymn,
                style: buttonStyle,
                isEnabled: !isPresenting && currentHymn != nil
            )
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
            .overlay(
                // Advanced animation overlays
                Group {
                    // Pulsing ring during loading
                    if isPresenting {
                        Circle()
                            .stroke(Color.green, lineWidth: 2)
                            .opacity(pulseOpacity)
                            .scaleEffect(1.2)
                    }
                    
                    // Success checkmark overlay with bounce
                    if showSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .scaleEffect(showSuccess ? 1.2 : 0.8)
                            .animation(.interpolatingSpring(stiffness: 200, damping: 10), value: showSuccess)
                    }
                }
            )
            .overlay(
                // Shimmer effect for available state
                shimmerOverlay
            )
            .rotationEffect(.degrees(iconRotation))
            .animation(.easeInOut(duration: 0.2), value: buttonScale)
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: iconRotation)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseOpacity)
            .symbolEffect(.pulse, isActive: isPresenting)
            .onAppear {
                startShimmerAnimation()
            }
            .alert("Present Hymn Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            if !isPresenting && !showSuccess {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60)
                    .rotationEffect(.degrees(20))
                    .offset(x: shimmerOffset)
                    .clipped()
            }
        }
    }
    
    private var buttonStyle: UniformControlButton.ButtonStyle {
        if let hymn = currentHymn,
           let worshipHymn = worshipSessionManager.currentWorshipHymn,
           hymn.id == worshipHymn.id {
            return .secondary // Already presenting - secondary style
        } else {
            return .primary // Available to present - primary style
        }
    }
    
    private var buttonOpacity: Double {
        if isPresenting {
            return 0.7
        } else if let hymn = currentHymn,
                  let worshipHymn = worshipSessionManager.currentWorshipHymn,
                  hymn.id == worshipHymn.id {
            return 0.8 // Slightly dimmed when already presenting
        } else {
            return 1.0
        }
    }
    
    /// Determines if the button should be visible
    private var shouldShowButton: Bool {
        // Must have an active worship session
        guard worshipSessionManager.isWorshipSessionActive else { return false }
        
        // Must have a current hymn to present
        guard let currentHymn = currentHymn else { return false }
        
        // Use enhanced state management - check if current state supports operations
        guard externalDisplayManager.state.supportsHymnSwitching || 
              externalDisplayManager.state.canPresentHymn else { return false }
        
        // Don't show if it's the same hymn already being presented
        if let worshipHymn = worshipSessionManager.currentWorshipHymn {
            return currentHymn.id != worshipHymn.id
        }
        
        // Show if we can present hymns in the current state
        return externalDisplayManager.state.canPresentHymn || 
               externalDisplayManager.state.supportsHymnSwitching
    }
    
    private var buttonIcon: String {
        if isPresenting {
            return "arrow.triangle.2.circlepath"
        } else if let hymn = currentHymn {
            // Check if this hymn is already being presented
            if let worshipHymn = worshipSessionManager.currentWorshipHymn,
               hymn.id == worshipHymn.id {
                return "checkmark.circle.fill"
            } else {
                return "play.tv.fill"
            }
        } else {
            return "play.tv.fill"
        }
    }
    
    private var buttonText: String {
        if isPresenting {
            return "Switching..."
        } else if let hymn = currentHymn {
            // Check if this hymn is already being presented
            if let worshipHymn = worshipSessionManager.currentWorshipHymn,
               hymn.id == worshipHymn.id {
                return "Currently\nPresenting"
            }
            
            // Smart truncation for hymn titles
            let title = hymn.title
            if title.count > 20 {
                // For very long titles, show first few words
                let words = title.components(separatedBy: " ")
                if words.count > 2 {
                    let truncated = words.prefix(2).joined(separator: " ")
                    return "Present\n\(truncated)..."
                } else {
                    return "Present\n\(String(title.prefix(15)))..."
                }
            } else if title.count > 12 {
                // For medium titles, break at a good point
                let words = title.components(separatedBy: " ")
                if words.count > 1 {
                    let midPoint = words.count / 2
                    let firstLine = words.prefix(midPoint).joined(separator: " ")
                    let secondLine = words.suffix(from: midPoint).joined(separator: " ")
                    return "\(firstLine)\n\(secondLine)"
                } else {
                    return "Present\n\(String(title.prefix(10)))..."
                }
            } else {
                return "Present\n\(title)"
            }
        } else {
            return "Present\nCurrent"
        }
    }
    
    // MARK: - Actions
    
    private func presentCurrentHymn() {
        guard let hymn = currentHymn else {
            // Error haptic
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            errorMessage = "No hymn selected to present"
            showError = true
            return
        }
        
        // Check if already presenting this hymn
        if let worshipHymn = worshipSessionManager.currentWorshipHymn,
           hymn.id == worshipHymn.id {
            // Light haptic for already presenting
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            return
        }
        
        // Start haptic for beginning action
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Advanced visual feedback
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 0.95
            iconRotation = 10
        }
        
        // Start pulsing animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.8
        }
        
        isPresenting = true
        
        Task {
            do {
                try await worshipSessionManager.presentCurrentlyViewedHymn(hymn)
                
                await MainActor.run {
                    isPresenting = false
                    
                    // Success haptic
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    // Success visual feedback
                    showSuccessFeedback()
                }
            } catch {
                await MainActor.run {
                    isPresenting = false
                    
                    // Error haptic
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    
                    // Reset button scale
                    withAnimation(.easeInOut(duration: 0.1)) {
                        buttonScale = 1.0
                    }
                    
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func showSuccessFeedback() {
        // Stop pulsing animation
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseOpacity = 0.0
        }
        
        // Reset button with bounce effect
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
            buttonScale = 1.0
            iconRotation = 0.0
        }
        
        // Show success overlay with entrance animation
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 20).delay(0.1)) {
            showSuccess = true
        }
        
        // Success celebration rotation
        withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
            iconRotation = 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showSuccess = false
                iconRotation = 0
            }
        }
    }
    
    private func startShimmerAnimation() {
        // Periodic shimmer effect for available buttons
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard !isPresenting && !showSuccess else { return }
            
            withAnimation(.easeInOut(duration: 1.5)) {
                shimmerOffset = 200
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                shimmerOffset = -200
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create sample data for preview
    struct PreviewWrapper: View {
        @StateObject private var externalDisplayManager = ExternalDisplayManager()
        @StateObject private var worshipSessionManager = WorshipSessionManager(externalDisplayManager: ExternalDisplayManager())
        
        var body: some View {
            VStack {
                PresentCurrentHymnButton(currentHymn: sampleHymn)
                    .environmentObject(externalDisplayManager)
                    .environmentObject(worshipSessionManager)
                    .onAppear {
                        // Set up preview state
                        worshipSessionManager.isWorshipSessionActive = true
                        externalDisplayManager.state = .worshipMode
                    }
                
                Text("Preview of Present Current Hymn Button")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        
        private var sampleHymn: Hymn {
            Hymn(
                title: "Amazing Grace",
                lyrics: "Amazing grace, how sweet the sound...",
                musicalKey: "G",
                author: "John Newton"
            )
        }
    }
    
    return PreviewWrapper()
}