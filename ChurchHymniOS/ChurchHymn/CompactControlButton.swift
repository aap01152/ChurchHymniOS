//
//  CompactControlButton.swift
//  ChurchHymn
//
//  Created by Claude on 20/12/2025.
//

import SwiftUI

/// Compact button layout optimized for smaller screens
/// Shows icon above text in vertical layout to save horizontal space
struct CompactControlButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(minWidth: 44, minHeight: 32)
    }
}

#Preview {
    HStack(spacing: 12) {
        CompactControlButton(icon: "chevron.left.circle.fill", text: "Previous")
            .buttonStyle(.bordered)
        
        CompactControlButton(icon: "chevron.right.circle.fill", text: "Next")
            .buttonStyle(.bordered)
        
        CompactControlButton(icon: "stop.circle.fill", text: "Stop")
            .buttonStyle(.bordered)
    }
    .padding()
}