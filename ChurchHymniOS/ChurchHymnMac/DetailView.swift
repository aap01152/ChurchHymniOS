import SwiftUI
import SwiftData

struct DetailView: View {
    let hymn: Hymn
    var currentPresentationIndex: Int?
    var isPresenting: Bool
    @Binding var lyricsFontSize: CGFloat
    
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
