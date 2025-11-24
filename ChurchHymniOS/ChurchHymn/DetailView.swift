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
            
            Text(NSLocalizedString("multiselect.mode", comment: "Multi-select mode title"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text(String(format: NSLocalizedString("count.hymns_selected", comment: "Selected hymns count"), selectedHymnsForDelete.count))
                .font(.title2)
                .foregroundColor(.secondary)
            
            if !selectedHymnsForDelete.isEmpty {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("multiselect.actions_available", comment: "Actions available text"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(NSLocalizedString("multiselect.delete_selected", comment: "Delete selected action"))
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("multiselect.export_selected", comment: "Export selected action"))
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
                    
                    Text(NSLocalizedString("status.select_hymn_to_start", comment: "Select hymn to start message"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(NSLocalizedString("status.import_info", comment: "Import info message"))
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("help.import_formats", comment: "Import formats title"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("help.json_single", comment: "JSON single hymn format"))
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
                        Text(NSLocalizedString("help.json_multiple", comment: "JSON multiple hymns format"))
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
                        Text(NSLocalizedString("help.plain_text", comment: "Plain text format"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(plainText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text(NSLocalizedString("help.chorus_instruction", comment: "Chorus instruction"))
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

 
