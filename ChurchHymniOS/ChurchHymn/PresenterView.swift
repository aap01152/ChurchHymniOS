//
//  PresenterView.swift
//  ChurchHymn
//
//  Created by paulo on 20/05/2025.
//
import SwiftUI

struct PresenterView: View {
    var hymn: Hymn
    var onIndexChange: (Int) -> Void
    var onDismiss: () -> Void
    @State private var index: Int = 0
    @Environment(\.dismiss) private var dismiss

    /// Sequence for presentation: if a chorus exists, repeat it after each verse;
    /// otherwise present each verse block in order.
    private var presentationParts: [(label: String?, lines: [String])] {
        let allBlocks = hymn.parts
        
        // Extract chorus blocks
        let choruses = allBlocks.filter { $0.label != nil }
        let verses = allBlocks.filter { $0.label == nil }
        
        // If we have a chorus, interleave verses and chorus
        if let chorusPart = choruses.first {
            var result: [(label: String?, lines: [String])] = []
            for verse in verses {
                result.append(verse)
                result.append(chorusPart)
            }
            return result
        } else {
            // No chorus: just return verses
            return verses
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            mainContent
        }
        .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            headerSection
            Spacer()
            lyricsSection
            Spacer()
            footerSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            onIndexChange(index)
        }
        .onDisappear {
            onDismiss()
        }
        .onChange(of: index) { _, newIndex in
            onIndexChange(newIndex)
        }
        .gesture(dragGesture)
        .onTapGesture {
            advance()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            retreat()
        }
    }
    
    private var headerSection: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    Text(hymn.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    if let key = hymn.musicalKey, !key.isEmpty {
                        Text("(\(key))")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                // Close button
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .help(NSLocalizedString("presentation.exit", comment: "Exit presentation help text"))
            }
            .padding(.top, UIDevice.current.userInterfaceIdiom == .phone ? safeTop + 48 : 24)
            .padding(.horizontal, 24)
        }
        .frame(height: 60) // Adjust as needed for layout
    }
    
    private var lyricsSection: some View {
        Group {
            if !presentationParts.isEmpty {
                Text(presentationParts[index].lines.joined(separator: "\n"))
                    .font(.system(size: 72, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            } else if let lyrics = hymn.lyrics, !lyrics.isEmpty {
                // Fallback: show raw lyrics if parts parsing failed
                Text(lyrics)
                    .font(.system(size: 56, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            } else {
                // Show a test message when no lyrics are available
                testMessageView
            }
        }
    }
    
    private var testMessageView: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("presentation.test_title", comment: "Test hymn display title"))
                .font(.system(size: 56))
                .foregroundColor(.white)
            Text(NSLocalizedString("presentation.test_message", comment: "Test presentation message"))
                .font(.system(size: 28))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("presentation.test_instructions", comment: "Test presentation instructions"))
                .font(.system(size: 20))
                .foregroundColor(.yellow)
        }
        .padding()
    }
    
    private var footerSection: some View {
        HStack {
            // Copyright bottom-left
            Text(hymn.copyright ?? "")
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            // Verse/Chorus bottom-right
            if !presentationParts.isEmpty {
                verseChorusLabel
            }
        }
        .padding([.bottom, .horizontal], 24)
    }
    
    private var verseChorusLabel: some View {
        HStack(spacing: 8) {
            Group {
                if let label = presentationParts[index].label {
                    Text(label)
                } else {
                    let verseNumber = presentationParts[0...index].filter { $0.label == nil }.count
                    Text(String(format: NSLocalizedString("external.verse_number", comment: "Verse number format"), verseNumber))
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            
            // Show end indicator if we're at the last part
            if index == presentationParts.count - 1 {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .symbolEffect(.pulse)
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height
                
                if abs(horizontalAmount) > abs(verticalAmount) {
                    // Horizontal swipe
                    if horizontalAmount > 0 {
                        retreat() // Swipe right to go back
                    } else {
                        advance() // Swipe left to go forward
                    }
                } else {
                    // Vertical swipe
                    if verticalAmount > 0 {
                        retreat() // Swipe down to go back
                    } else {
                        advance() // Swipe up to go forward
                    }
                }
            }
    }
    
    private func advance() {
        // Only advance if we're not at the last part
        if index < presentationParts.count - 1 {
            index += 1
        }
    }
    
    private func retreat() {
        // Only retreat if we're not at the first part
        if index > 0 {
            index -= 1
        }
    }
}
