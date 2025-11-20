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
                headerSection
                    .frame(height: geometry.size.height * 0.15)
                
                Spacer()
                
                lyricsSection
                    .frame(maxHeight: geometry.size.height * 0.7)
                
                Spacer()
                
                footerSection
                    .frame(height: geometry.size.height * 0.15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    // Large, bold title for maximum readability at distance
                    Text(hymn.title)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    // Musical key in high-contrast yellow
                    if let key = hymn.musicalKey, !key.isEmpty {
                        Text("Key: \(key)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 32)
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
                    Text("No Lyrics Available")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text("Please check the hymn content")
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .multilineTextAlignment(.center)
            }
        }
    }
    
    private var footerSection: some View {
        HStack {
            // Copyright and author info with better contrast
            VStack(alignment: .leading, spacing: 6) {
                if let copyright = hymn.copyright, !copyright.isEmpty {
                    Text(copyright)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                
                if let author = hymn.author, !author.isEmpty {
                    Text("By: \(author)")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
            
            Spacer()
            
            // Verse indicator with enhanced visibility
            if !presentationParts.isEmpty {
                verseIndicator
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
    }
    
    private var verseIndicator: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // Current verse/chorus label with high visibility
            if verseIndex < presentationParts.count {
                let currentPart = presentationParts[verseIndex]
                if let label = currentPart.label {
                    Text(label)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    let verseNumber = presentationParts[0...verseIndex].filter { $0.label == nil }.count
                    Text("Verse \(verseNumber)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
            
            // Progress indicator with better visibility
            Text("\(verseIndex + 1) of \(presentationParts.count)")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}