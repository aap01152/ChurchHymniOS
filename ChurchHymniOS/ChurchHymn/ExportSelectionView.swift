import SwiftUI

struct ExportSelectionView: View {
    let hymns: [Hymn]
    @Binding var selectedHymns: Set<UUID>
    @Binding var exportFormat: ExportFormat
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary and format selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected: \(selectedHymns.count) hymn\(selectedHymns.count == 1 ? "" : "s")")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Total available: \(hymns.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button("Select All") {
                                selectedHymns = Set(hymns.map { $0.id })
                            }
                            .disabled(selectedHymns.count == hymns.count)
                            .buttonStyle(.bordered)
                            
                            Button("Clear All") {
                                selectedHymns.removeAll()
                            }
                            .disabled(selectedHymns.isEmpty)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export Format")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Format", selection: $exportFormat) {
                            ForEach(ExportFormat.allCases, id: \.self) { format in
                                Text(format.description).tag(format)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Hymn list
                List {
                    ForEach(hymns) { hymn in
                        ExportSelectionHymnRow(
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
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Export Hymns")
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
                    Button("Export") {
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
            // If no hymns are selected, select the first one by default
            if selectedHymns.isEmpty && !hymns.isEmpty {
                selectedHymns.insert(hymns.first!.id)
            }
        }
    }
}

struct ExportSelectionHymnRow: View {
    let hymn: Hymn
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
                Text(hymn.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
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