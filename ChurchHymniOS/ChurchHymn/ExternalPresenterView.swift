//
//  ExternalPresenterView.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//
//  PHASE 2: External Presentation View
//  - Clean, projector-optimized layout designed for congregation readability
//  - Large fonts optimized for distance viewing
//  - High contrast color scheme (white text on black background)
//  - No interactive elements - purely for display
//

import SwiftUI

struct ExternalPresenterView: View {
    let hymn: Hymn
    let verseIndex: Int
    
    private var presentationParts: [(label: String?, lines: [String])] {
        let allBlocks = hymn.parts
        
        let choruses = allBlocks.filter { $0.label != nil }
        let verses = allBlocks.filter { $0.label == nil }
        
        if let chorusPart = choruses.first {
            var result: [(label: String?, lines: [String])] = []
            for verse in verses {
                result.append(verse)
                result.append(chorusPart)
            }
            return result
        } else {
            return verses
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                titleSection
                    .frame(height: geometry.size.height * 0.1)
                
                Spacer()
                
                lyricsSection
                    .frame(maxHeight: geometry.size.height * 0.9)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
    }
    
    private var titleSection: some View {
        Text(hymn.title)
            .font(.system(size: 36, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 20)
            .padding(.top, 16)
    }
    
    private var lyricsSection: some View {
        VStack {
            if !presentationParts.isEmpty && verseIndex < presentationParts.count {
                let currentPart = presentationParts[verseIndex]
                Text(currentPart.lines.joined(separator: "\n"))
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(16) // Increased line spacing for better readability
                    .minimumScaleFactor(0.4) // Higher minimum scale to maintain readability
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1) // Subtle shadow for better contrast
                    .padding(.horizontal, 60)
            } else if let lyrics = hymn.lyrics, !lyrics.isEmpty {
                // Fallback for non-parsed lyrics
                Text(lyrics)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(16)
                    .minimumScaleFactor(0.4)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .padding(.horizontal, 60)
            } else {
                // No lyrics message in high contrast
                VStack(spacing: 16) {
                    Text(NSLocalizedString("external.no_lyrics_available", comment: "No lyrics available message"))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text(NSLocalizedString("external.check_hymn_content", comment: "Check hymn content message"))
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .multilineTextAlignment(.center)
            }
        }
    }
    
}