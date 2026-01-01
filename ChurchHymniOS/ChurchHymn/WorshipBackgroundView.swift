//
//  WorshipBackgroundView.swift
//  ChurchHymn
//
//  Created by Claude on 13/12/2025.
//

import SwiftUI

/// Background view displayed on external screen during worship sessions
/// Shows a serene image to maintain visual continuity between hymn presentations
struct WorshipBackgroundView: View {
    let imageName: String
    @State private var imageLoadFailed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color fallback
                backgroundGradient
                    .ignoresSafeArea(.all)
                
                // Main background image with fallback handling
                Group {
                    if !imageLoadFailed {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .ignoresSafeArea(.all)
                            .onAppear {
                                // Validate image exists
                                if UIImage(named: imageName) == nil {
                                    imageLoadFailed = true
                                }
                            }
                    } else {
                        fallbackBackgroundView
                    }
                }
                
                // Subtle vignette overlay
                vignetteOverlay
                    .ignoresSafeArea(.all)
                
                // App branding overlay
                brandingOverlay(screenSize: geometry.size)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Background Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color(.systemGray6).opacity(0.3),
                Color.black
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var fallbackBackgroundView: some View {
        ZStack {
            // Elegant fallback pattern
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemIndigo).opacity(0.8),
                    Color(.systemPurple).opacity(0.6),
                    Color(.systemBlue).opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle texture overlay
            Circle()
                .fill(Color.white.opacity(0.03))
                .scaleEffect(2.5)
                .blur(radius: 100)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(Color.white.opacity(0.02))
                .scaleEffect(3.0)
                .blur(radius: 150)
                .offset(x: 300, y: 200)
        }
    }
    
    private var vignetteOverlay: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.1),
                Color.black.opacity(0.3)
            ]),
            center: .center,
            startRadius: 100,
            endRadius: 800
        )
    }
    
    @ViewBuilder
    private func brandingOverlay(screenSize: CGSize) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // App name with elegant typography
                    Text(NSLocalizedString("worship_bg.church_hymn", comment: "ChurchHymn"))
                        .font(.system(size: adaptiveFontSize(base: 28, screenSize: screenSize), weight: .light, design: .serif))
                        .foregroundColor(.white)
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                    
                    // Status indicator with better visibility
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                            .font(.system(size: adaptiveFontSize(base: 14, screenSize: screenSize), weight: .ultraLight))
                            .foregroundColor(.white)
                            .opacity(0.5)
                        
                        Text(NSLocalizedString("worship_bg.session_active", comment: "Worship Session Active"))
                            .font(.system(size: adaptiveFontSize(base: 16, screenSize: screenSize), weight: .ultraLight, design: .default))
                            .foregroundColor(.white)
                            .opacity(0.5)
                    }
                    
                    // Subtle timestamp for context
                    Text(getCurrentTimeString())
                        .font(.system(size: adaptiveFontSize(base: 12, screenSize: screenSize), weight: .ultraLight, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.3)
                        .padding(.top, 4)
                }
                .padding(.trailing, adaptivePadding(base: 60, screenSize: screenSize))
                .padding(.bottom, adaptivePadding(base: 50, screenSize: screenSize))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func adaptiveFontSize(base: CGFloat, screenSize: CGSize) -> CGFloat {
        let scale = min(screenSize.width / 1920, screenSize.height / 1080)
        return max(base * scale, base * 0.7) // Ensure minimum readable size
    }
    
    private func adaptivePadding(base: CGFloat, screenSize: CGSize) -> CGFloat {
        let scale = min(screenSize.width / 1920, screenSize.height / 1080)
        return max(base * scale, base * 0.5)
    }
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#Preview {
    WorshipBackgroundView(imageName: "serene")
        .frame(width: 1920, height: 1080)
        .background(Color.black)
}