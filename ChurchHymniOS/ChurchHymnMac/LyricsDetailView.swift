//
//  LyricsDetailView.swift
//  ChurchHymn
//
//  Created by paulo on 20/05/2025.
//
import SwiftUI

struct LyricsDetailView: View {
    let hymn: Hymn
    var currentPresentationIndex: Int?
    var isPresenting: Bool
    @Binding var lyricsFontSize: CGFloat
    
    @Namespace private var scrollSpace
    
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
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if hymn.lyrics != nil {
                        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                            VStack(alignment: .leading, spacing: 8) {
                                // Part label (if any)
                                if let label = part.label {
                                    Text(label)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Verse \(parts[0..<index].filter { $0.label == nil }.count + 1)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Lyrics
                                Text(part.lines.joined(separator: "\n"))
                                    .font(.system(size: lyricsFontSize))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isPresenting && currentPresentationIndex == index ? 
                                                  Color.accentColor.opacity(0.1) : Color.clear)
                                    )
                                    .animation(.easeInOut(duration: 0.3), value: currentPresentationIndex)
                            }
                            .id(index) // Add id for scrolling
                        }
                    } else {
                        Text("No lyrics available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
            }
            .onChange(of: currentPresentationIndex) { _, newIndex in
                if let index = newIndex {
                    // Scroll to the current verse with animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                } else {
                    // When presentation ends, scroll to top
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(0, anchor: .top)
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
}
