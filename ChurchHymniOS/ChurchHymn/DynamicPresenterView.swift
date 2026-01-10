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
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    var body: some View {
        if let currentHymn = selected {
            PresenterView(
                hymn: currentHymn,
                onIndexChange: { newIndex in
                    // Sync verse changes with external display if presenting
                    if externalDisplayManager.isPresenting && externalDisplayManager.currentHymn?.id == currentHymn.id {
                        externalDisplayManager.goToVerse(newIndex)
                    }
                },
                onDismiss: onDismiss
            )
            .id(currentHymn.id) // Force view refresh when hymn changes
        } else {
            // Fallback view if no hymn is selected
            VStack {
                Text(NSLocalizedString("status.no_hymn_selected", comment: "No hymn selected"))
                    .font(.title)
                    .foregroundColor(.secondary)
                
                Button(NSLocalizedString("btn.close", comment: "Close")) {
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
    Text(NSLocalizedString("preview.dynamic_presenter", comment: "Dynamic presenter preview"))
        .padding()
        .foregroundColor(.secondary)
        .font(.caption)
}
