import SwiftUI

// MARK: - Import Preview
struct ImportPreviewHymn: Identifiable {
    let id = UUID()
    let title: String
    let lyrics: String?
    let musicalKey: String?
    let author: String?
    let copyright: String?
    let notes: String?
    let tags: [String]?
    let songNumber: Int?
    let isDuplicate: Bool
    let existingHymn: Hymn?
    
    init(from hymn: Hymn, isDuplicate: Bool = false, existingHymn: Hymn? = nil) {
        self.title = hymn.title
        self.lyrics = hymn.lyrics
        self.musicalKey = hymn.musicalKey
        self.author = hymn.author
        self.copyright = hymn.copyright
        self.notes = hymn.notes
        self.tags = hymn.tags
        self.songNumber = hymn.songNumber
        self.isDuplicate = isDuplicate
        self.existingHymn = existingHymn
    }
}

struct ImportPreview: @unchecked Sendable {
    let hymns: [ImportPreviewHymn]
    let duplicates: [ImportPreviewHymn]
    let errors: [String]
    let fileName: String
    
    var totalHymns: Int { hymns.count + duplicates.count }
    var validHymns: Int { hymns.count }
    var duplicateCount: Int { duplicates.count }
    var errorCount: Int { errors.count }
}

// MARK: - Import Preview View
struct ImportPreviewView: View {
    let preview: ImportPreview
    @Binding var selectedHymns: Set<UUID>
    @Binding var duplicateResolution: DuplicateResolution
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with summary
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("File: \(preview.fileName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            ImportSummaryItem(label: "Total", count: preview.totalHymns, color: .blue)
                            ImportSummaryItem(label: "New", count: preview.validHymns, color: .green)
                            ImportSummaryItem(label: "Duplicates", count: preview.duplicateCount, color: .orange)
                            if preview.errorCount > 0 {
                                ImportSummaryItem(label: "Errors", count: preview.errorCount, color: .red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Duplicate resolution picker
                    if preview.duplicateCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Duplicate Resolution")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Resolution", selection: $duplicateResolution) {
                                ForEach(DuplicateResolution.allCases, id: \.self) { resolution in
                                    Text(resolution.description).tag(resolution)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // Hymn list
                List {
                    if !preview.hymns.isEmpty {
                        Section("New Hymns (\(preview.validHymns))") {
                            ForEach(preview.hymns) { hymn in
                                ImportPreviewHymnRow(
                                    hymn: hymn,
                                    isSelected: selectedHymns.contains(hymn.id),
                                    onToggle: { isSelected in
                                        if isSelected {
                                            selectedHymns.insert(hymn.id)
                                        } else {
                                            selectedHymns.remove(hymn.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    if !preview.duplicates.isEmpty {
                        Section("Duplicates (\(preview.duplicateCount))") {
                            ForEach(preview.duplicates) { hymn in
                                ImportPreviewHymnRow(
                                    hymn: hymn,
                                    isSelected: selectedHymns.contains(hymn.id),
                                    onToggle: { isSelected in
                                        if isSelected {
                                            selectedHymns.insert(hymn.id)
                                        } else {
                                            selectedHymns.remove(hymn.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    if !preview.errors.isEmpty {
                        Section("Errors (\(preview.errorCount))") {
                            ForEach(preview.errors, id: \.self) { error in
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.body)
                                    Text(error)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onConfirm()
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .disabled(selectedHymns.isEmpty)
                }
            }
        }
        .onAppear {
            // Select all hymns by default
            selectedHymns = Set(preview.hymns.map { $0.id } + preview.duplicates.map { $0.id })
        }
    }
}

struct ImportSummaryItem: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}

struct ImportPreviewHymnRow: View {
    let hymn: ImportPreviewHymn
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(hymn.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if hymn.isDuplicate {
                        Text("(Duplicate)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemOrange).opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                HStack(spacing: 16) {
                    if let author = hymn.author, !author.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .foregroundColor(.secondary)
                            Text(author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let key = hymn.musicalKey, !key.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                            Text(key)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let lyrics = hymn.lyrics, !lyrics.isEmpty {
                    Text(lyrics.prefix(120) + (lyrics.count > 120 ? "..." : ""))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
