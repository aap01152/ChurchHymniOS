import SwiftUI
import SwiftData

struct DetailView: View {
    let hymn: Hymn
    var currentPresentationIndex: Int?
    var isPresenting: Bool
    @Binding var lyricsFontSize: CGFloat
    
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Title and metadata
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(hymn.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if let number = hymn.songNumber {
                            HStack(spacing: 4) {
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(.blue.opacity(0.4))
                                Text("#\(number)")
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        if let key = hymn.musicalKey {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue.opacity(0.4))
                                Text(key)
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        if let author = hymn.author {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue.opacity(0.4))
                                Text(author)
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let copyright = hymn.copyright {
                    HStack(spacing: 4) {
                        Image(systemName: "c.circle")
                            .foregroundColor(.blue.opacity(0.4))
                        Text(copyright)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let tags = hymn.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // External Display Status
                if externalDisplayManager.state != .disconnected {
                    ExternalDisplayStatusInDetailView(hymn: hymn)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Lyrics with highlighting
            LyricsDetailView(
                hymn: hymn,
                currentPresentationIndex: currentPresentationIndex,
                isPresenting: isPresenting,
                lyricsFontSize: $lyricsFontSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct MultiSelectDetailView: View {
    let selectedHymnsForDelete: Set<UUID>
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Multi-Select Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("\(selectedHymnsForDelete.count) hymn\(selectedHymnsForDelete.count == 1 ? "" : "s") selected")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if !selectedHymnsForDelete.isEmpty {
                VStack(spacing: 8) {
                    Text("Actions Available:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("• Delete selected hymns")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("• Export selected hymns")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct EmptyDetailView: View {
    private let jsonSingle = """
{
  "title": "Amazing Grace",
  "songNumber": 123,
  "lyrics": "Amazing grace, how sweet the sound...",
  "musicalKey": "C",
  "author": "John Newton",
  "copyright": "Public Domain",
  "tags": ["grace", "salvation"],
  "notes": "Traditional hymn"
}
"""

    private let jsonBatch = """
[
  { "title": "Hymn 1", "lyrics": "..." },
  { "title": "Hymn 2", "lyrics": "..." }
]
"""

    private let plainText = """
Amazing Grace
#Number: 123
#Key: C
#Author: John Newton
#Copyright: Public Domain
#Tags: grace, salvation
#Notes:

Amazing grace, how sweet the sound
That saved a wretch like me
…

Chorus
Praise God, praise God, praise God
"""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Select a hymn to get started")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("You can also import .txt or .json files to add hymns to your collection")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Import Formats")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("JSON – Single Hymn")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(jsonSingle)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("JSON – Multiple Hymns")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(jsonBatch)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Plain Text")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(plainText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text("Put the word 'Chorus' on a line by itself before the chorus section.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ExternalDisplayStatusInDetailView: View {
    let hymn: Hymn
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                Spacer()
                if externalDisplayManager.state == .presenting && externalDisplayManager.currentHymn?.id == hymn.id {
                    Text("\(externalDisplayManager.currentVerseIndex + 1) of \(externalDisplayManager.totalVerses)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Enhanced verse navigation for active presentation
            if externalDisplayManager.state == .presenting && externalDisplayManager.currentHymn?.id == hymn.id {
                VStack(spacing: 8) {
                    // Current verse highlight
                    Text("Currently Displaying:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(externalDisplayManager.currentVerseInfo)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color(.systemFill))
                        .cornerRadius(8)
                    
                    // Navigation controls
                    HStack(spacing: 12) {
                        Button(action: externalDisplayManager.previousVerse) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!externalDisplayManager.canGoToPreviousVerse)
                        
                        Spacer()
                        
                        // Preview window reminder for iPad
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.inset.filled")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text("Preview Window")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                Text("Check bottom-right corner")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: externalDisplayManager.nextVerse) {
                            HStack(spacing: 4) {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!externalDisplayManager.canGoToNextVerse)
                    }
                }
            } else if externalDisplayManager.state == .connected {
                // Quick start button for this specific hymn
                Button(action: startPresentationForThisHymn) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Present This Hymn Externally")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(statusBackgroundColor)
        .cornerRadius(8)
    }
    
    private func startPresentationForThisHymn() {
        do {
            try externalDisplayManager.startPresentation(hymn: hymn)
        } catch {
            print("Failed to start presentation: \(error)")
        }
    }
    
    private var statusIcon: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "tv.slash"
        case .connected:
            return "tv"
        case .presenting:
            return externalDisplayManager.currentHymn?.id == hymn.id ? "tv.fill" : "tv"
        }
    }
    
    private var statusColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            return .blue
        case .presenting:
            return externalDisplayManager.currentHymn?.id == hymn.id ? .green : .orange
        }
    }
    
    private var statusText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "External Display Disconnected"
        case .connected:
            return "External Display Ready"
        case .presenting:
            if externalDisplayManager.currentHymn?.id == hymn.id {
                return "Presenting on External Display"
            } else {
                return "External Display Showing Different Hymn"
            }
        }
    }
    
    private var statusBackgroundColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return Color.gray.opacity(0.1)
        case .connected:
            return Color.blue.opacity(0.1)
        case .presenting:
            return externalDisplayManager.currentHymn?.id == hymn.id ? Color.green.opacity(0.1) : Color.orange.opacity(0.1)
        }
    }
} 
