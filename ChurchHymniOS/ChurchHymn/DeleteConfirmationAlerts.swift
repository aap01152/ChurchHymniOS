import SwiftUI

struct DeleteConfirmationAlerts: ViewModifier {
    let hymns: [Hymn]
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    let onDeleteHymn: () -> Void
    let onDeleteSelectedHymns: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Delete Hymn", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDeleteHymn()
                }
            } message: {
                if let hymn = hymnToDelete {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Are you sure you want to delete this hymn?")
                            .font(.headline)
                        
                        Text("Title: \(hymn.title)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let lyrics = hymn.lyrics, !lyrics.isEmpty {
                            Text("Lyrics: \(lyrics.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("This action cannot be undone.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .alert("Delete Multiple Hymns", isPresented: $showingBatchDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete \(selectedHymnsForDelete.count) Hymn\(selectedHymnsForDelete.count == 1 ? "" : "s")", role: .destructive) {
                    onDeleteSelectedHymns()
                }
            } message: {
                let selectedHymns = hymns.filter { selectedHymnsForDelete.contains($0.id) }
                let totalCharacters = selectedHymns.reduce(0) { sum, hymn in
                    sum + (hymn.lyrics?.count ?? 0)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Are you sure you want to delete \(selectedHymnsForDelete.count) hymn\(selectedHymnsForDelete.count == 1 ? "" : "s")?")
                        .font(.headline)
                    
                    if selectedHymnsForDelete.count <= 5 {
                        ForEach(selectedHymns, id: \.id) { hymn in
                            Text("• \(hymn.title)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        let titleList = selectedHymns.prefix(3).map { $0.title }.joined(separator: ", ")
                        let remainingCount = selectedHymnsForDelete.count - 3
                        
                        Text("• \(titleList)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• ...and \(remainingCount) more")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Total content: \(totalCharacters) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("This action cannot be undone.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
    }
}

extension View {
    func deleteConfirmationAlerts(
        hymns: [Hymn],
        showingDeleteConfirmation: Binding<Bool>,
        showingBatchDeleteConfirmation: Binding<Bool>,
        hymnToDelete: Binding<Hymn?>,
        selectedHymnsForDelete: Binding<Set<UUID>>,
        onDeleteHymn: @escaping () -> Void,
        onDeleteSelectedHymns: @escaping () -> Void
    ) -> some View {
        modifier(DeleteConfirmationAlerts(
            hymns: hymns,
            showingDeleteConfirmation: showingDeleteConfirmation,
            showingBatchDeleteConfirmation: showingBatchDeleteConfirmation,
            hymnToDelete: hymnToDelete,
            selectedHymnsForDelete: selectedHymnsForDelete,
            onDeleteHymn: onDeleteHymn,
            onDeleteSelectedHymns: onDeleteSelectedHymns
        ))
    }
} 