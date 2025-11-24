import SwiftUI

struct StreamingProgressOverlay: View {
    let isStreaming: Bool
    let progress: StreamingProgress?
    let message: String
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Progress card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                // Title
                Text(NSLocalizedString("progress.streaming_operation", comment: "Streaming operation title"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Progress bars
                VStack(spacing: 12) {
                    // File progress
                    if let progress = progress, progress.totalBytes > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("progress.file_progress", comment: "File progress label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: progress.percentage, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 300)
                            
                            Text("\(formatBytes(progress.bytesProcessed)) / \(formatBytes(progress.totalBytes))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Hymn progress
                    if let progress = progress, let totalHymns = progress.totalHymns, totalHymns > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("progress.hymn_processing", comment: "Hymn processing label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: progress.hymnsPercentage, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 300)
                            
                            Text("\(progress.hymnsProcessed) / \(totalHymns) hymns")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Overall percentage
                    if let progress = progress {
                        Text("\(Int(progress.percentage * 100))%")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                
                // Phase information
                if let progress = progress {
                    Text(progress.currentPhase)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Message
                if !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 400)
                }
                
                // Memory usage indicator
                if progress != nil {
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("progress.memory_efficient_processing", comment: "Memory efficient processing text"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Cancel button
                Button(NSLocalizedString("btn.cancel", comment: "Cancel button")) {
                    // TODO: Implement cancellation
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 
