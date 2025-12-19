//
//  LyricsDetailView.swift
//  ChurchHymn
//
//  Created by paulo on 20/05/2025.
//
import SwiftUI

enum VerseInteractionState {
    case readOnly
    case availablePresenting
    case activePresenting
}

struct LyricsDetailView: View {
    let hymn: Hymn
    var currentPresentationIndex: Int?
    var isPresenting: Bool
    @Binding var lyricsFontSize: CGFloat
    
    @Namespace private var scrollSpace
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    // MARK: - Enhanced Visual Feedback Properties
    
    /// Determines if verse interaction is enabled based on external display state
    private var isInteractiveMode: Bool {
        externalDisplayManager.state == .presenting
    }
    
    /// Gets the interaction state for a specific verse
    private func verseInteractionState(for index: Int) -> VerseInteractionState {
        if externalDisplayManager.state == .presenting && isCurrentExternalVerse(index) {
            return .activePresenting
        }
        if externalDisplayManager.state == .presenting {
            return .availablePresenting
        }
        return .readOnly
    }
    
    // MARK: - Enhanced Visual Styling Methods
    
    /// Gets the background color for a verse based on its interaction state
    private func backgroundStyle(for index: Int) -> some View {
        let state = verseInteractionState(for: index)
        
        switch state {
        case .readOnly:
            return RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        case .availablePresenting:
            return RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        case .activePresenting:
            return RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.3))
        }
    }
    
    /// Gets the border style for a verse based on its interaction state
    private func borderStyle(for index: Int) -> some View {
        let state = verseInteractionState(for: index)
        
        switch state {
        case .readOnly:
            return RoundedRectangle(cornerRadius: 8)
                .stroke(Color.clear, lineWidth: 0)
        case .availablePresenting:
            return RoundedRectangle(cornerRadius: 8)
                .stroke(Color.clear, lineWidth: 0)
        case .activePresenting:
            return RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
        }
    }
    
    /// Gets the scale effect for a verse based on its interaction state
    private func scaleEffect(for index: Int) -> CGFloat {
        let state = verseInteractionState(for: index)
        
        switch state {
        case .readOnly, .availablePresenting:
            return 1.0
        case .activePresenting:
            return 1.03
        }
    }
    
    /// Gets shadow properties for active presenting verses
    private func shadowStyle(for index: Int) -> some View {
        let state = verseInteractionState(for: index)
        
        if state == .activePresenting {
            return AnyView(
                Color.accentColor
                    .opacity(0.4)
                    .blur(radius: 8)
                    .offset(x: 0, y: 2)
            )
        } else {
            return AnyView(Color.clear)
        }
    }
    
    private var parts: [(label: String?, lines: [String])] {
        let allBlocks = hymn.parts
        // Extract chorus blocks
        let choruses = allBlocks.filter { $0.label != nil }
        let verses = allBlocks.filter { $0.label == nil }
        if let chorusPart = choruses.first {
            // Interleave verse and chorus
            return verses.flatMap { [$0, chorusPart] }
        } else {
            // No chorus: just show each verse block
            return verses
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if hymn.lyrics != nil {
                        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                            VStack(alignment: .leading, spacing: 8) {
                                // Part label with live indicator
                                HStack {
                                    if let label = part.label {
                                        Text(label)
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(String(format: NSLocalizedString("external.verse_number", comment: "Verse number format"), parts[0..<index].filter { $0.label == nil }.count + 1))
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Live indicator for actively presented verse
                                    if verseInteractionState(for: index) == .activePresenting {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 8, height: 8)
                                                .opacity(0.8)
                                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: externalDisplayManager.currentVerseIndex)
                                            
                                            Text("LIVE")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Lyrics with enhanced visual feedback
                                Text(part.lines.joined(separator: "\n"))
                                    .font(.system(size: lyricsFontSize))
                                    .lineSpacing(4)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        ZStack {
                                            // Shadow for active presenting verses
                                            shadowStyle(for: index)
                                            // Main background with subtle border for better definition
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.systemBackground))
                                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                            // Enhanced background for active state
                                            backgroundStyle(for: index)
                                                .overlay(borderStyle(for: index))
                                        }
                                    )
                                    .scaleEffect(scaleEffect(for: index))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPresentationIndex)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.9), value: externalDisplayManager.state)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.9), value: externalDisplayManager.currentVerseIndex)
                                    .onTapGesture {
                                        if isInteractiveMode {
                                            // Provide immediate haptic feedback
                                            provideHapticFeedback(for: index)
                                            
                                            // Navigate to the selected verse
                                            externalDisplayManager.goToVerse(index)
                                            
                                            // Provide success feedback after a brief delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                provideNavigationSuccessFeedback()
                                            }
                                        }
                                    }
                                    .accessibilityAddTraits(isInteractiveMode ? .isButton : [])
                                    .accessibilityHint(accessibilityHint(for: index))
                                    .accessibilityValue(verseInteractionState(for: index) == .activePresenting ? NSLocalizedString("verse.currently_displayed", comment: "Currently displayed") : "")
                            }
                            .id(index) // Add id for scrolling
                        }
                    } else {
                        Text(NSLocalizedString("status.no_lyrics_available", comment: "No lyrics available"))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .padding(.bottom, 40) // Extra bottom padding to ensure last verse is fully visible
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottom) {
                // Subtle gradient to indicate scrollability at bottom
                LinearGradient(
                    colors: [Color.clear, Color(.systemGroupedBackground).opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
            .onChange(of: currentPresentationIndex) { _, newIndex in
                if let index = newIndex {
                    // Scroll to the current verse with animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .top)
                    }
                } else {
                    // When presentation ends, scroll to top
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
            }
            .onChange(of: externalDisplayManager.currentVerseIndex) { _, newVerseIndex in
                // Auto-scroll to top when verse changes on external display
                if externalDisplayManager.state.isPresenting {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(newVerseIndex, anchor: .top)
                    }
                }
            }
            .onChange(of: externalDisplayManager.state) { _, newState in
                // Auto-scroll when external presentation starts
                if newState.isPresenting {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(externalDisplayManager.currentVerseIndex, anchor: .top)
                    }
                }
            }
            .onChange(of: isPresenting) { _, presenting in
                if !presenting {
                    // When presentation ends, scroll to top
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
            }
        }
    }
    
    /// Helper function to determine if a verse is currently being presented
    private func isCurrentVerse(_ index: Int) -> Bool {
        return isPresenting && currentPresentationIndex == index
    }
    
    /// Helper function to determine if a verse is currently being displayed on external screen
    private func isCurrentExternalVerse(_ index: Int) -> Bool {
        return externalDisplayManager.currentVerseIndex == index
    }
    
    /// Provides accessibility hint based on verse interaction state
    private func accessibilityHint(for index: Int) -> String {
        let state = verseInteractionState(for: index)
        
        switch state {
        case .readOnly:
            return ""
        case .availablePresenting:
            return NSLocalizedString("verse.tap_to_navigate", comment: "Tap to navigate hint")
        case .activePresenting:
            return NSLocalizedString("verse.tap_to_navigate_current", comment: "Tap to navigate from current verse hint")
        }
    }
    
    // MARK: - Enhanced Haptic Feedback System
    
    /// Provides contextual haptic feedback based on verse interaction type
    private func provideHapticFeedback(for index: Int) {
        let state = verseInteractionState(for: index)
        
        switch state {
        case .readOnly:
            // No haptic feedback for read-only state
            return
            
        case .availablePresenting:
            // Medium impact for navigating to different verse
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
        case .activePresenting:
            // Light impact for staying on current verse (user confirmation)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
    
    /// Provides success haptic feedback when verse navigation completes
    private func provideNavigationSuccessFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Provides selection haptic feedback for precise interactions
    private func provideSelectionFeedback() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
}