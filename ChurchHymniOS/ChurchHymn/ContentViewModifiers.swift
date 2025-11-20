import SwiftUI
import SwiftData

struct ContentViewModifiers: ViewModifier {
    let hymns: [Hymn]
    let selected: Hymn?
    let newHymn: Hymn?
    let context: ModelContext
    let operations: HymnOperations
    
    // Sheet states
    @Binding var showingEdit: Bool
    @Binding var showingImportPreview: Bool
    @Binding var showingExportSelection: Bool
    @Binding var importPreview: ImportPreview?
    @Binding var selectedHymnsForImport: Set<UUID>
    @Binding var duplicateResolution: DuplicateResolution
    @Binding var selectedHymnsForExport: Set<UUID>
    @Binding var exportFormat: ExportFormat
    
    // Callbacks
    let onSave: (Hymn) -> Void
    let onCleanupEmptyHymn: () -> Void
    let onConfirmImport: () -> Void
    let onCancelImport: () -> Void
    let onConfirmExport: () -> Void
    let onCancelExport: () -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingEdit) {
                if let hymn = selected { 
                    HymnEditView(hymn: hymn, onSave: onSave)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: showingEdit) { _, isShowing in
                if !isShowing {
                    onCleanupEmptyHymn()
                }
            }
            .sheet(isPresented: $showingImportPreview) {
                if let preview = importPreview {
                    ImportPreviewView(
                        preview: preview,
                        selectedHymns: $selectedHymnsForImport,
                        duplicateResolution: $duplicateResolution,
                        onConfirm: onConfirmImport,
                        onCancel: onCancelImport
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingExportSelection) {
                ExportSelectionView(
                    hymns: hymns,
                    selectedHymns: $selectedHymnsForExport,
                    exportFormat: $exportFormat,
                    onConfirm: onConfirmExport,
                    onCancel: onCancelExport
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay(
                Group {
                    if operations.isImporting || operations.isExporting {
                        ProgressOverlay(
                            isImporting: operations.isImporting,
                            isExporting: operations.isExporting,
                            progress: operations.isImporting ? operations.importProgress : operations.exportProgress,
                            message: operations.progressMessage
                        )
                    } else if operations.streamingOperations.isStreaming {
                        StreamingProgressOverlay(
                            isStreaming: operations.streamingOperations.isStreaming,
                            progress: operations.streamingOperations.streamingProgress,
                            message: operations.streamingOperations.streamingMessage
                        )
                    }
                }
            )
    }
}

extension View {
    func contentViewModifiers(
        hymns: [Hymn],
        selected: Hymn?,
        newHymn: Hymn?,
        context: ModelContext,
        operations: HymnOperations,
        showingEdit: Binding<Bool>,
        showingImportPreview: Binding<Bool>,
        showingExportSelection: Binding<Bool>,
        importPreview: Binding<ImportPreview?>,
        selectedHymnsForImport: Binding<Set<UUID>>,
        duplicateResolution: Binding<DuplicateResolution>,
        selectedHymnsForExport: Binding<Set<UUID>>,
        exportFormat: Binding<ExportFormat>,
        onSave: @escaping (Hymn) -> Void,
        onCleanupEmptyHymn: @escaping () -> Void,
        onConfirmImport: @escaping () -> Void,
        onCancelImport: @escaping () -> Void,
        onConfirmExport: @escaping () -> Void,
        onCancelExport: @escaping () -> Void
    ) -> some View {
        modifier(ContentViewModifiers(
            hymns: hymns,
            selected: selected,
            newHymn: newHymn,
            context: context,
            operations: operations,
            showingEdit: showingEdit,
            showingImportPreview: showingImportPreview,
            showingExportSelection: showingExportSelection,
            importPreview: importPreview,
            selectedHymnsForImport: selectedHymnsForImport,
            duplicateResolution: duplicateResolution,
            selectedHymnsForExport: selectedHymnsForExport,
            exportFormat: exportFormat,
            onSave: onSave,
            onCleanupEmptyHymn: onCleanupEmptyHymn,
            onConfirmImport: onConfirmImport,
            onCancelImport: onCancelImport,
            onConfirmExport: onConfirmExport,
            onCancelExport: onCancelExport
        ))
    }
} 