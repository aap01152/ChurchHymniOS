import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import Foundation

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @Query(sort: \Hymn.title, order: .forward) private var hymns: [Hymn]
    
    // Core state
    @State private var selected: Hymn? = nil
    @State private var newHymn: Hymn? = nil
    @State private var showingEdit = false
    @State private var editHymn: Hymn? = nil
    @State private var presentedHymnIndex: Int? = nil
    @State private var isPresenting = false
    
    // Tab selection state
    @State private var selectedTab = 0
    
    // Import/Export state
    @State private var exportType: ExportType?
    @State private var importType: ImportType?
    @State private var currentImportType: ImportType?
    @State private var showingImportHelp = false
    @State private var showingManageWindow = false
    
    // Error handling states
    @State private var importError: ImportError?
    @State private var showingErrorAlert = false
    @State private var importSuccessMessage: String?
    @State private var showingSuccessAlert = false
    
    // Import preview states
    @State private var importPreview: ImportPreview?
    @State private var showingImportPreview = false
    @State private var selectedHymnsForImport: Set<UUID> = []
    @State private var duplicateResolution: DuplicateResolution = .skip
    
    // Export selection states
    @State private var showingExportSelection = false
    @State private var selectedHymnsForExport: Set<UUID> = []
    @State private var exportFormat: ExportFormat = .json
    
    // Delete confirmation states
    @State private var showingDeleteConfirmation = false
    @State private var hymnToDelete: Hymn?
    
    // Multi-select states for batch delete
    @State private var selectedHymnsForDelete: Set<UUID> = []
    @State private var isMultiSelectMode = false
    @State private var showingBatchDeleteConfirmation = false
    
    // Font size state
    @State private var lyricsFontSize: CGFloat = 16
    
    // Navigation split view visibility state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Operations
    @StateObject private var operations: HymnOperations
    
    // Computed bindings to reduce type-check complexity in modifiers
    private var isImportPresentedBinding: Binding<Bool> {
        Binding<Bool>(
            get: { importType != nil },
            set: { presented in
                if !presented { importType = nil }
            }
        )
    }
    
    private var isExportPresentedBinding: Binding<Bool> {
        Binding<Bool>(
            get: { exportType != nil },
            set: { presented in
                if !presented {
                    exportType = nil
                    cleanupAfterExport()
                }
            }
        )
    }
    
    init() {
        // Initialize operations with a temporary context - will be updated in onAppear
        self._operations = StateObject(wrappedValue: HymnOperations(context: ModelContext(try! ModelContainer(for: Hymn.self))))
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use two-column split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    HymnListView(
                        hymns: hymns,
                        selected: $selected,
                        selectedHymnsForDelete: $selectedHymnsForDelete,
                        isMultiSelectMode: $isMultiSelectMode,
                        editHymn: $editHymn,
                        showingEdit: $showingEdit,
                        hymnToDelete: $hymnToDelete,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                        newHymn: $newHymn,
                        importType: $importType,
                        currentImportType: $currentImportType,
                        selectedHymnsForExport: $selectedHymnsForExport,
                        showingExportSelection: $showingExportSelection,
                        showingImportHelp: $showingImportHelp,
                        showingManageWindow: $showingManageWindow,
                        context: context,
                        onPresent: onPresentHymn
                    )
                    .navigationTitle(NSLocalizedString("nav.library", comment: "Navigation title for library"))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ExternalDisplayNavigationIndicator()
                        }
                    }
                    .frame(minWidth: 320)
                } detail: {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            HymnToolbarView(
                                hymns: hymns,
                                selected: $selected,
                                selectedHymnsForDelete: $selectedHymnsForDelete,
                                isMultiSelectMode: $isMultiSelectMode,
                                showingEdit: $showingEdit,
                                newHymn: $newHymn,
                                importType: $importType,
                                currentImportType: $currentImportType,
                                selectedHymnsForExport: $selectedHymnsForExport,
                                showingExportSelection: $showingExportSelection,
                                hymnToDelete: $hymnToDelete,
                                showingDeleteConfirmation: $showingDeleteConfirmation,
                                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                                lyricsFontSize: $lyricsFontSize,
                                context: context,
                                openWindow: openWindow,
                                onPresent: onPresentHymn
                            )
                            Spacer()
                        }
                        .padding(.top, 16)
                        
                        // External Display Status Bar - PHASE 3 Integration
                        if externalDisplayManager.state != .disconnected {
                            VStack(spacing: 0) {
                                ExternalDisplayStatusBar()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                
                                if externalDisplayManager.state == .connected || externalDisplayManager.state == .presenting {
                                    ExternalDisplayQuickControls(selectedHymn: selected)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                }
                            }
                            .background(Color(.systemBackground))
                        }
                        
                        Divider()
                        VStack {
                            if isMultiSelectMode {
                                MultiSelectDetailView(selectedHymnsForDelete: selectedHymnsForDelete)
                            } else if let hymn = selected {
                                DetailView(
                                    hymn: hymn,
                                    currentPresentationIndex: presentedHymnIndex,
                                    isPresenting: isPresenting,
                                    lyricsFontSize: $lyricsFontSize
                                )
                            } else {
                                EmptyDetailView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // iPhone: Use TabView as before
                TabView(selection: $selectedTab) {
                    // Tab 1: Search & Song List (no detail view)
                    HymnListView(
                        hymns: hymns,
                        selected: $selected,
                        selectedHymnsForDelete: $selectedHymnsForDelete,
                        isMultiSelectMode: $isMultiSelectMode,
                        editHymn: $editHymn,
                        showingEdit: $showingEdit,
                        hymnToDelete: $hymnToDelete,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                        newHymn: $newHymn,
                        importType: $importType,
                        currentImportType: $currentImportType,
                        selectedHymnsForExport: $selectedHymnsForExport,
                        showingExportSelection: $showingExportSelection,
                        showingImportHelp: $showingImportHelp,
                        showingManageWindow: $showingManageWindow,
                        context: context,
                        onPresent: onPresentHymn
                    )
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text(NSLocalizedString("nav.library", comment: "Tab title for library"))
                    }
                    .tag(0)
                    
                    
                    // Tab 2: Toolbar with scrolling detail view
                    VStack(spacing: 0) {
                        // Toolbar at the top
                        HStack {
                            Spacer()
                            HymnToolbarView(
                                hymns: hymns,
                                selected: $selected,
                                selectedHymnsForDelete: $selectedHymnsForDelete,
                                isMultiSelectMode: $isMultiSelectMode,
                                showingEdit: $showingEdit,
                                newHymn: $newHymn,
                                importType: $importType,
                                currentImportType: $currentImportType,
                                selectedHymnsForExport: $selectedHymnsForExport,
                                showingExportSelection: $showingExportSelection,
                                hymnToDelete: $hymnToDelete,
                                showingDeleteConfirmation: $showingDeleteConfirmation,
                                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                                lyricsFontSize: $lyricsFontSize,
                                context: context,
                                openWindow: openWindow,
                                onPresent: onPresentHymn
                            )
                            Spacer()
                        }
                        .padding(.top, 16)
                        
                        // External Display Status Bar - PHASE 3 Integration (iPhone)
                        if externalDisplayManager.state != .disconnected {
                            VStack(spacing: 0) {
                                ExternalDisplayStatusBar()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                
                                if externalDisplayManager.state == .connected || externalDisplayManager.state == .presenting {
                                    ExternalDisplayQuickControls(selectedHymn: selected)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                }
                            }
                            .background(Color(.systemBackground))
                        }
                        
                        Divider()
                        
                        VStack {
                            if isMultiSelectMode {
                                MultiSelectDetailView(selectedHymnsForDelete: selectedHymnsForDelete)
                                } else if let hymn = selected {
                                    DetailView(
                                        hymn: hymn,
                                        currentPresentationIndex: presentedHymnIndex,
                                        isPresenting: isPresenting,
                                        lyricsFontSize: $lyricsFontSize
                                    )
                            } else {
                                EmptyDetailView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tabItem {
                        Image(systemName: "music.note")
                        Text(NSLocalizedString("nav.song", comment: "Tab title for song"))
                    }
                    .tag(1)
                }
            }
        }
        .overlay {
            // PHASE 4: External Display Preview Window
            if UIDevice.current.userInterfaceIdiom == .pad {
                ManagedExternalDisplayPreview()
                    .allowsHitTesting(true)
            }
        }
        .fileImporter(
            isPresented: isImportPresentedBinding,
            allowedContentTypes: importType == .auto ? [UTType.json, UTType.plainText] : (importType == .json ? [UTType.json] : [UTType.plainText]),
            allowsMultipleSelection: true
        ) { result in
            let importTypeToUse = importType ?? currentImportType
            handleImportResult(result, importType: importTypeToUse)
        }
        .fileExporter(
            isPresented: isExportPresentedBinding,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportDefaultFilename
        ) { result in
            if case let .success(url) = result, let type = exportType {
                handleExportResult(type, url: url)
            }
        }
        .alert(NSLocalizedString("alert.import_error", comment: "Import error alert title"), isPresented: $showingErrorAlert, presenting: importError) { error in
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: { error in
            Text(error.detailedErrorDescription)
        }
        .alert(NSLocalizedString("alert.import_successful", comment: "Import success alert title"), isPresented: $showingSuccessAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: {
            Text(importSuccessMessage ?? NSLocalizedString("msg.hymn_imported_successfully", comment: "Default import success message"))
        }
        .deleteConfirmationAlerts(
            hymns: hymns,
            showingDeleteConfirmation: $showingDeleteConfirmation,
            showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
            hymnToDelete: $hymnToDelete,
            selectedHymnsForDelete: $selectedHymnsForDelete,
            onDeleteHymn: deleteHymn,
            onDeleteSelectedHymns: deleteSelectedHymns
        )
        .contentViewModifiers(
            hymns: hymns,
            selected: selected,
            newHymn: newHymn,
            context: context,
            operations: operations,
            showingEdit: $showingEdit,
            showingImportPreview: $showingImportPreview,
            showingExportSelection: $showingExportSelection,
            importPreview: $importPreview,
            selectedHymnsForImport: $selectedHymnsForImport,
            duplicateResolution: $duplicateResolution,
            selectedHymnsForExport: $selectedHymnsForExport,
            exportFormat: $exportFormat,
            onSave: { savedHymn in
                try? context.save()
                if newHymn == savedHymn {
                    newHymn = nil
                }
            },
            onCleanupEmptyHymn: cleanupEmptyHymn,
            onConfirmImport: confirmImport,
            onCancelImport: cancelImport,
            onConfirmExport: confirmExport,
            onCancelExport: cancelExport
        )
        .onAppear {
            // Update operations context with the actual context
            operations.updateContext(context)
        }
        .fullScreenCover(isPresented: $isPresenting) {
            if let hymn = selected {
                PresenterView(
                    hymn: hymn,
                    onIndexChange: { index in
                        presentedHymnIndex = index
                    },
                    onDismiss: {
                        presentedHymnIndex = nil
                        isPresenting = false
                    }
                )
            }
        }
    }

    // MARK: - Actions
    
    private func onPresentHymn(_ hymn: Hymn) {
        if let index = hymns.firstIndex(where: { $0.id == hymn.id }) {
            presentedHymnIndex = index
            isPresenting = true
        }
    }
    
    private func addNewHymn() {
        let hymn = Hymn(title: "")
        context.insert(hymn)
        newHymn = hymn
        selected = hymn
        showingEdit = true
    }
    
    private func importHymns() {
        importType = .auto
        currentImportType = .auto
    }
    
    private func editCurrentHymn() {
        if selected != nil {
            showingEdit = true
        }
    }
    
    private func exportSelectedHymn() {
        if let hymn = selected {
            selectedHymnsForExport = [hymn.id]
            showingExportSelection = true
        }
    }
    
    private func exportMultipleHymns() {
        showingExportSelection = true
    }
    
    private func exportAllHymns() {
        selectedHymnsForExport = Set(hymns.map { $0.id })
        showingExportSelection = true
    }
    
    private func present(_ hymn: Hymn) {
        // iOS/iPadOS presentation - use full screen cover
        presentedHymnIndex = 0
        isPresenting = true
    }
    
    private func deleteHymn() {
        guard let hymn = hymnToDelete else { return }
        
        context.delete(hymn)
        
        if selected == hymn {
            selected = nil
        }
        if editHymn == hymn {
            editHymn = nil
        }
        if newHymn == hymn {
            newHymn = nil
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving after delete: \(error)")
        }
        
        hymnToDelete = nil
        showingDeleteConfirmation = false
    }
    
    private func deleteSelectedHymns() {
        let hymnsToDelete = hymns.filter { selectedHymnsForDelete.contains($0.id) }
        
        for hymn in hymnsToDelete {
            context.delete(hymn)
            
            if selected == hymn {
                selected = nil
            }
            if editHymn == hymn {
                editHymn = nil
            }
            if newHymn == hymn {
                newHymn = nil
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving after batch delete: \(error)")
        }
        
        selectedHymnsForDelete.removeAll()
        isMultiSelectMode = false
        showingBatchDeleteConfirmation = false
    }
    
    private func cleanupEmptyHymn() {
        if let hymn = newHymn, hymn.title.trimmingCharacters(in: .whitespaces).isEmpty {
            context.delete(hymn)
            
            if selected == hymn {
                selected = nil
            }
            if editHymn == hymn {
                editHymn = nil
            }
            newHymn = nil
            
            do {
                try context.save()
            } catch {
                print("Error saving after cleanup: \(error)")
            }
        }
    }
    
    private func cleanupAfterExport() {
        selectedHymnsForExport.removeAll()
    }
    
    // MARK: - Import/Export Handlers
    
    private func handleImportResult(_ result: Result<[URL], Error>, importType: ImportType?) {
        print("DEBUG: importType parameter = \(String(describing: importType))")
        
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                showError(.unknown("No files selected"))
                return
            }
            
            guard let importType = importType else {
                showError(.unknown("Unknown import type"))
                return
            }
            
            // Process each file
            Task {
                var allHymns: [ImportPreviewHymn] = []
                var allDuplicates: [ImportPreviewHymn] = []
                var allErrors: [String] = []
                
                for (_, url) in urls.enumerated() {
                    // Start accessing security scoped resource for sandboxed app
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // Auto-detect file type and size for intelligent import
                    let actualImportType = detectImportType(for: url, requestedType: importType)
                    
                    do {
                        let preview: ImportPreview = try await withCheckedThrowingContinuation { continuation in
                            switch actualImportType {
                            case .plainText:
                                operations.importPlainTextHymn(
                                    from: url,
                                    hymns: hymns,
                                    onComplete: { preview in
                                        continuation.resume(returning: preview)
                                    },
                                    onError: { error in
                                        continuation.resume(throwing: error)
                                    }
                                )
                            case .json:
                                // Check file size to determine if streaming is needed
                                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                                let largeFileThreshold = 10 * 1024 * 1024 // 10MB
                                
                                if fileSize > largeFileThreshold {
                                    operations.importLargeJSONStreaming(
                                        from: url,
                                        hymns: hymns,
                                        onComplete: { preview in
                                            continuation.resume(returning: preview)
                                        },
                                        onError: { error in
                                            continuation.resume(throwing: error)
                                        }
                                    )
                                } else {
                                    operations.importBatchJSON(
                                        from: url,
                                        hymns: hymns,
                                        onComplete: { preview in
                                            continuation.resume(returning: preview)
                                        },
                                        onError: { error in
                                            continuation.resume(throwing: error)
                                        }
                                    )
                                }
                            case .auto:
                                continuation.resume(throwing: ImportError.unknown("Auto detection failed"))
                            }
                        }
                        
                        // Collect results from this file
                        allHymns.append(contentsOf: preview.hymns)
                        allDuplicates.append(contentsOf: preview.duplicates)
                        allErrors.append(contentsOf: preview.errors)
                        
                    } catch let error as ImportError {
                        allErrors.append("Error importing \(url.lastPathComponent): \(error.localizedDescription)")
                    } catch {
                        allErrors.append("Unexpected error importing \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                
                // Show combined preview for all files
                let combinedPreview = ImportPreview(
                    hymns: allHymns,
                    duplicates: allDuplicates,
                    errors: allErrors,
                    fileName: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
                )
                
                await MainActor.run {
                    operations.isImporting = false  // Reset the importing state
                    operations.importProgress = 0.0 // Reset progress
                    operations.progressMessage = "" // Clear message
                    importPreview = combinedPreview
                    showingImportPreview = true
                }
            }
            
        case .failure(let error):
            let nsError = error as NSError
            let specificError = getSpecificFileError(nsError)
            showError(specificError)
            operations.isImporting = false  // Reset the importing state on error
            operations.importProgress = 0.0 // Reset progress
            operations.progressMessage = "" // Clear message
        }
        
        currentImportType = nil
    }
    
    private func handleExportResult(_ type: ExportType, url: URL) {
        switch type {
        case .singlePlainText:
            if let hymn = selected {
                operations.exportPlainTextHymn(
                    hymn,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            }
        case .singleJSON:
            if let hymn = selected {
                operations.exportSingleJSONHymn(
                    hymn,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            }
        case .multipleJSON:
            let hymnsToExport = hymns.filter { selectedHymnsForExport.contains($0.id) }
            let largeCollectionThreshold = 1000 // Use streaming for collections > 1000 hymns
            
            if hymnsToExport.count > largeCollectionThreshold {
                operations.exportLargeJSONStreaming(
                    hymns: hymnsToExport,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            } else {
                operations.exportBatchJSON(
                    hymnsToExport,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            }
        case .batchJSON:
            let largeCollectionThreshold = 1000 // Use streaming for collections > 1000 hymns
            
            if hymns.count > largeCollectionThreshold {
                operations.exportLargeJSONStreaming(
                    hymns: hymns,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            } else {
                operations.exportBatchJSON(
                    hymns,
                    to: url,
                    onComplete: { },
                    onError: { error in
                        showError(error)
                    }
                )
            }
        }
    }
    
    // MARK: - Import Preview Functions
    
    private func confirmImport() {
        guard let preview = importPreview else { return }
        
        let selectedValidHymns = preview.hymns.filter { selectedHymnsForImport.contains($0.id) }
        let selectedDuplicateHymns = preview.duplicates.filter { selectedHymnsForImport.contains($0.id) }
        
        var hymnsToImport: [Hymn] = []
        var duplicatesToProcess: [DuplicateHymn] = []
        
        for previewHymn in selectedValidHymns {
            let hymn = Hymn(
                title: previewHymn.title,
                lyrics: previewHymn.lyrics,
                musicalKey: previewHymn.musicalKey,
                copyright: previewHymn.copyright,
                author: previewHymn.author,
                tags: previewHymn.tags,
                notes: previewHymn.notes,
                songNumber: previewHymn.songNumber
            )
            hymnsToImport.append(hymn)
        }
        
        for previewHymn in selectedDuplicateHymns {
            if let existingHymn = previewHymn.existingHymn {
                let newHymn = Hymn(
                    title: previewHymn.title,
                    lyrics: previewHymn.lyrics,
                    musicalKey: previewHymn.musicalKey,
                    copyright: previewHymn.copyright,
                    author: previewHymn.author,
                    tags: previewHymn.tags,
                    notes: previewHymn.notes,
                    songNumber: previewHymn.songNumber
                )
                duplicatesToProcess.append(DuplicateHymn(existing: existingHymn, new: newHymn))
            }
        }
        
        processFinalImport(validHymns: hymnsToImport, duplicates: duplicatesToProcess, errors: preview.errors)
    }
    
    private func cancelImport() {
        showingImportPreview = false
        importPreview = nil
        selectedHymnsForImport.removeAll()
        operations.isImporting = false  // Reset the importing state
        operations.importProgress = 0.0 // Reset progress
        operations.progressMessage = "" // Clear message
    }
    
    private func processFinalImport(validHymns: [Hymn], duplicates: [DuplicateHymn], errors: [String]) {
        Task {
            await MainActor.run {
                operations.isImporting = true
                operations.importProgress = 0.0
                operations.progressMessage = "Processing import..."
            }
            
            do {
                let totalItems = validHymns.count + duplicates.count
                var processedItems = 0
                
                switch duplicateResolution {
                case .skip:
                    break
                case .merge:
                    for duplicate in duplicates {
                        await MainActor.run {
                            operations.importProgress = Double(processedItems) / Double(totalItems)
                            operations.progressMessage = "Merging duplicate: \(duplicate.newHymn.title)..."
                        }
                        mergeHymnData(existing: duplicate.existingHymn, new: duplicate.newHymn)
                        processedItems += 1
                    }
                case .replace:
                    for duplicate in duplicates {
                        await MainActor.run {
                            operations.importProgress = Double(processedItems) / Double(totalItems)
                            operations.progressMessage = "Replacing duplicate: \(duplicate.newHymn.title)..."
                        }
                        replaceHymnData(existing: duplicate.existingHymn, new: duplicate.newHymn)
                        processedItems += 1
                    }
                }
                
                for hymn in validHymns {
                    await MainActor.run {
                        operations.importProgress = Double(processedItems) / Double(totalItems)
                        operations.progressMessage = "Importing hymn: \(hymn.title)..."
                    }
                    context.insert(hymn)
                    processedItems += 1
                }
                
                await MainActor.run {
                    operations.importProgress = 0.9
                    operations.progressMessage = "Saving to database..."
                }
                
                try context.save()
                
                await MainActor.run {
                    operations.importProgress = 1.0
                    operations.progressMessage = "Import complete!"
                }
                
                var message = "Successfully imported \(validHymns.count) hymn\(validHymns.count == 1 ? "" : "s")"
                
                if !duplicates.isEmpty {
                    let duplicateCount = duplicates.count
                    switch duplicateResolution {
                    case .skip:
                        message += ". Skipped \(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")"
                    case .merge:
                        message += ". Merged \(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")"
                    case .replace:
                        message += ". Replaced \(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s")"
                    }
                }
                
                if !errors.isEmpty {
                    message += ". \(errors.count) error\(errors.count == 1 ? "" : "s") encountered"
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    operations.isImporting = false
                    showSuccess(message)
                }
                
            } catch {
                await MainActor.run {
                    operations.isImporting = false
                }
                showError(.unknown("Failed to save imported hymns: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Export Functions
    
    private func confirmExport() {
        let hymnsToExport = hymns.filter { selectedHymnsForExport.contains($0.id) }
        
        if hymnsToExport.isEmpty {
            showError(.unknown("No hymns selected for export"))
            return
        }
        
        if hymnsToExport.count == 1 {
            exportType = exportFormat == .json ? .singleJSON : .singlePlainText
        } else {
            exportType = exportFormat == .json ? .multipleJSON : .batchJSON
        }
        
        showingExportSelection = false
    }
    
    private func cancelExport() {
        showingExportSelection = false
        selectedHymnsForExport.removeAll()
    }
    
    // MARK: - Helper Functions
    
    private func showError(_ error: ImportError) {
        importError = error
        showingErrorAlert = true
    }
    
    private func showSuccess(_ message: String) {
        importSuccessMessage = message
        showingSuccessAlert = true
    }
    
    private func mergeHymnData(existing: Hymn, new: Hymn) {
        if (existing.lyrics?.isEmpty ?? true) && !(new.lyrics?.isEmpty ?? true) {
            existing.lyrics = new.lyrics
        }
        if (existing.musicalKey?.isEmpty ?? true) && !(new.musicalKey?.isEmpty ?? true) {
            existing.musicalKey = new.musicalKey
        }
        if (existing.author?.isEmpty ?? true) && !(new.author?.isEmpty ?? true) {
            existing.author = new.author
        }
        if (existing.copyright?.isEmpty ?? true) && !(new.copyright?.isEmpty ?? true) {
            existing.copyright = new.copyright
        }
        if (existing.notes?.isEmpty ?? true) && !(new.notes?.isEmpty ?? true) {
            existing.notes = new.notes
        }
        if (existing.tags?.isEmpty ?? true) && !(new.tags?.isEmpty ?? true) {
            existing.tags = new.tags
        }
        if existing.songNumber == nil && new.songNumber != nil {
            existing.songNumber = new.songNumber
        }
    }
    
    private func replaceHymnData(existing: Hymn, new: Hymn) {
        existing.lyrics = new.lyrics
        existing.musicalKey = new.musicalKey
        existing.author = new.author
        existing.copyright = new.copyright
        existing.notes = new.notes
        existing.tags = new.tags
        existing.songNumber = new.songNumber
    }
    
    // MARK: - File Type Detection
    
    private func detectImportType(for url: URL, requestedType: ImportType) -> ImportType {
        // If a specific type was requested, use it
        if requestedType != .auto {
            return requestedType
        }
        
        // Auto-detect based on file extension and content
        let fileExtension = url.pathExtension.lowercased()
        
        // Check file extension first
        if fileExtension == "json" {
            return .json
        } else if fileExtension == "txt" || fileExtension.isEmpty {
            // For .txt files or files without extension, check content
            return detectContentType(for: url)
        }
        
        // Default to plain text for unknown extensions
        return .plainText
    }
    
    private func detectContentType(for url: URL) -> ImportType {
        do {
            let data = try Data(contentsOf: url)
            
            // Try to parse as JSON first
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                // If it's valid JSON, check if it looks like hymn data
                if let jsonDict = jsonObject as? [String: Any] {
                    // Single hymn object
                    if jsonDict["title"] != nil {
                        return .json
                    }
                } else if let jsonArray = jsonObject as? [[String: Any]] {
                    // Array of hymn objects
                    if !jsonArray.isEmpty && jsonArray.first?["title"] != nil {
                        return .json
                    }
                }
            }
            
            // If not JSON, treat as plain text
            return .plainText
            
        } catch {
            // If we can't read the file, default to plain text
            return .plainText
        }
    }
    
    private func getSpecificFileError(_ error: NSError) -> ImportError {
        switch error.code {
        case NSFileReadNoPermissionError:
            return .permissionDenied
        case NSFileReadNoSuchFileError:
            return .fileNotFound
        case NSFileReadCorruptFileError:
            return .corruptedData("File appears to be corrupted")
        case NSFileReadInapplicableStringEncodingError:
            return .invalidFormat("File encoding is not supported. Please ensure the file uses UTF-8 encoding.")
        case NSFileReadTooLargeError:
            return .fileReadFailed("File is too large to read")
        case NSFileReadUnknownStringEncodingError:
            return .invalidFormat("Unknown file encoding. Please ensure the file uses UTF-8 encoding.")
        default:
            return .fileReadFailed(error.localizedDescription)
        }
    }
    
    // MARK: - File Exporter Helpers
    
    private var exportDocument: some FileDocument {
        struct ExportDoc: FileDocument {
            static var readableContentTypes: [UTType] = [.plainText, .json]
            var data: Data
            init(data: Data) { self.data = data }
            init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
            func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
        }
        switch exportType {
        case .singlePlainText:
            if let hymn = selected {
                return ExportDoc(data: (hymn.toPlainText().data(using: .utf8) ?? Data()))
            }
        case .singleJSON:
            if let hymn = selected, let data = hymn.toJSON(pretty: true) {
                return ExportDoc(data: data)
            }
        case .multipleJSON:
            let hymnsToExport = hymns.filter { selectedHymnsForExport.contains($0.id) }
            if let data = Hymn.arrayToJSON(hymnsToExport, pretty: true) {
                return ExportDoc(data: data)
            }
        case .batchJSON:
            if let data = Hymn.arrayToJSON(hymns, pretty: true) {
                return ExportDoc(data: data)
            }
        case .none:
            break
        }
        return ExportDoc(data: Data())
    }
    
    private var exportContentType: UTType {
        switch exportType {
        case .singlePlainText: return .plainText
        case .singleJSON, .multipleJSON, .batchJSON: return .json
        default: return .plainText
        }
    }
    
    private var exportDefaultFilename: String {
        switch exportType {
        case .singlePlainText: return (selected?.title ?? NSLocalizedString("nav.song", comment: "Default hymn name")) + ".txt"
        case .singleJSON: return (selected?.title ?? NSLocalizedString("nav.song", comment: "Default hymn name")) + ".json"
        case .multipleJSON: return "\(NSLocalizedString("export.selected", comment: "Selected hymns filename"))_Hymns.json"
        case .batchJSON: return "Hymns.json"
        default: return NSLocalizedString("btn.export", comment: "Default export filename")
        }
    }
}
