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
            .alert(NSLocalizedString("alert.delete_hymn", comment: "Delete hymn alert title"), isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("btn.cancel", comment: "Cancel button"), role: .cancel) { }
                Button(NSLocalizedString("btn.delete", comment: "Delete button"), role: .destructive) {
                    onDeleteHymn()
                }
            } message: {
                if let hymn = hymnToDelete {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("msg.delete_hymn_confirm", comment: "Delete hymn confirmation"))
                            .font(.headline)
                        
                        Text("\(NSLocalizedString("form.title", comment: "Title label")): \(hymn.title)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let lyrics = hymn.lyrics, !lyrics.isEmpty {
                            Text(String(format: NSLocalizedString("count.lyrics_chars", comment: "Lyrics character count"), lyrics.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(NSLocalizedString("msg.action_cannot_be_undone", comment: "Action cannot be undone warning"))
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .alert(NSLocalizedString("alert.delete_multiple_hymns", comment: "Delete multiple hymns alert title"), isPresented: $showingBatchDeleteConfirmation) {
                Button(NSLocalizedString("btn.cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(format: NSLocalizedString("btn.delete_count", comment: "Delete count button"), selectedHymnsForDelete.count), role: .destructive) {
                    onDeleteSelectedHymns()
                }
            } message: {
                let selectedHymns = hymns.filter { selectedHymnsForDelete.contains($0.id) }
                let totalCharacters = selectedHymns.reduce(0) { sum, hymn in
                    sum + (hymn.lyrics?.count ?? 0)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: NSLocalizedString("msg.delete_multiple_hymns_confirm", comment: "Delete multiple hymns confirmation"), selectedHymnsForDelete.count))
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
                        
                        Text(String(format: NSLocalizedString("count.and_more", comment: "And more count"), remainingCount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(format: NSLocalizedString("count.total_content_chars", comment: "Total content characters"), totalCharacters))
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