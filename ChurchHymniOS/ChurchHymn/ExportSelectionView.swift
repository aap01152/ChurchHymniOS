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
                            Text(String(format: NSLocalizedString("count.selected_hymns", comment: "Selected hymns count"), selectedHymns.count))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(String(format: NSLocalizedString("count.total_available", comment: "Total available count"), hymns.count))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(NSLocalizedString("btn.select_all", comment: "Select all button")) {
                                selectedHymns = Set(hymns.map { $0.id })
                            }
                            .disabled(selectedHymns.count == hymns.count)
                            .buttonStyle(.bordered)
                            
                            Button(NSLocalizedString("btn.clear_all", comment: "Clear all button")) {
                                selectedHymns.removeAll()
                            }
                            .disabled(selectedHymns.isEmpty)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("export.format", comment: "Export format label"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker(NSLocalizedString("export.format", comment: "Format picker"), selection: $exportFormat) {
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
            .navigationTitle(NSLocalizedString("nav.export_hymns", comment: "Export hymns navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("btn.cancel", comment: "Cancel button")) {
                        onCancel()
                        dismiss()
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("btn.export", comment: "Export button")) {
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