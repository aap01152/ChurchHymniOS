import SwiftUI

struct ProgressOverlay: View {
    let isImporting: Bool
    let isExporting: Bool
    let progress: Double
    let message: String
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Progress card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: isImporting ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isImporting ? .blue : .green)
                
                // Title
                Text(isImporting ? NSLocalizedString("progress.importing_hymns", comment: "Importing hymns progress title") : NSLocalizedString("progress.exporting_hymns", comment: "Exporting hymns progress title"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 300)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message
                if !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                // Cancel button (only for imports)
                if isImporting {
                    Button(NSLocalizedString("btn.cancel", comment: "Cancel button")) {
                        // TODO: Implement cancellation
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
        }
    }
} 