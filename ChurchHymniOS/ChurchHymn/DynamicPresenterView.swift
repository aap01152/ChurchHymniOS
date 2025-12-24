//
//  DynamicPresenterView.swift
//  ChurchHymn
//
//  Created by Claude on 20/12/2025.
//

import SwiftUI

/// A wrapper view that allows dynamic hymn switching during presentation
struct DynamicPresenterView: View {
    @ObservedObject var hymnService: HymnService
    @Binding var selected: Hymn?
    var onDismiss: () -> Void
    
    var body: some View {
        if let currentHymn = selected {
            PresenterView(
                hymn: currentHymn,
                onIndexChange: { _ in
                    // Index change is handled by the parent ContentView
                },
                onDismiss: onDismiss
            )
            .id(currentHymn.id) // Force view refresh when hymn changes
        } else {
            // Fallback view if no hymn is selected
            VStack {
                Text("No hymn selected")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
        }
    }
}

#Preview {
    Text("DynamicPresenterView Preview")
        .padding()
        .foregroundColor(.secondary)
        .font(.caption)
}