import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import Foundation

struct ContentView: View {
    @EnvironmentObject private var serviceFactory: ServiceFactory
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    
    // Service layer instances
    @State private var hymnService: HymnService?
    @State private var serviceService: ServiceService?
    @State private var servicesInitialized = false
    
    // Help system
    @StateObject private var helpSystem = HelpSystem()
    
    // Core state
    @State private var selected: Hymn? = nil
    @State private var newHymn: Hymn? = nil
    @State private var showingEdit = false
    @State private var editHymn: Hymn? = nil
    @State private var presentedHymnIndex: Int? = nil
    @State private var isPresenting = false
    
    // Tab selection state
    @State private var selectedTab = 0
    
    // Multi-select states for batch operations
    @State private var selectedHymnsForDelete: Set<UUID> = []
    @State private var isMultiSelectMode = false
    @State private var showingBatchDeleteConfirmation = false
    
    // Delete confirmation states
    @State private var showingDeleteConfirmation = false
    @State private var hymnToDelete: Hymn?
    
    // Service management states
    @State private var showingServiceManagement = false
    @State private var isServiceBarCollapsed = false
    
    // Import/Export states
    @State private var importExportManager: ImportExportManager?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var importType: ImportType = .auto
    @State private var exportFormat: ExportFormat = .json
    @State private var selectedHymnsForExport: Set<UUID> = []
    @State private var showingExportSelection = false
    @State private var showingImportPreview = false
    @State private var importPreview: ImportPreview?
    @State private var exportHymns: [Hymn] = []
    
    // Alert states for import/export
    @State private var importError: ImportExportError?
    @State private var showingImportErrorAlert = false
    @State private var importSuccessMessage: String?
    @State private var showingImportSuccessAlert = false
    @State private var exportSuccessMessage: String?
    @State private var showingExportSuccessAlert = false
    
    // Font size state
    @State private var lyricsFontSize: CGFloat = 24
    
    // Navigation split view visibility state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Force toolbar refresh when app becomes active
    @State private var toolbarRefreshTrigger = false

    var body: some View {
        Group {
            if let hymnService = hymnService, let serviceService = serviceService {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad: Use two-column split view
                    iPadLayout(hymnService: hymnService, serviceService: serviceService)
                } else {
                    // iPhone: Use TabView
                    iPhoneLayout(hymnService: hymnService, serviceService: serviceService)
                }
            } else {
                // Loading view while services are being initialized
                LoadingServicesView()
                    .task {
                        await initializeServices()
                    }
            }
        }
        // COMMENTED OUT: External Display Preview Window
        // Disabled floating preview window as there's already sufficient feedback
        // about external display state in the status bar
        /*
        .overlay {
            // External Display Preview Window
            if UIDevice.current.userInterfaceIdiom == .pad {
                ManagedExternalDisplayPreview()
                    .allowsHitTesting(true)
            }
        }
        */
        .alert("Delete Hymn", isPresented: $showingDeleteConfirmation, presenting: hymnToDelete) { hymn in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteHymn(hymn)
                }
            }
        } message: { hymn in
            Text("Are you sure you want to delete '\(hymn.title)'?")
        }
        .alert("Delete Multiple Hymns", isPresented: $showingBatchDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedHymns()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(selectedHymnsForDelete.count) hymns?")
        }
        .alert(NSLocalizedString("alert.import_error", comment: "Import error alert title"), isPresented: $showingImportErrorAlert, presenting: importError) { error in
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: { error in
            Text(error.detailedErrorDescription)
        }
        .alert(NSLocalizedString("alert.import_successful", comment: "Import success alert title"), isPresented: $showingImportSuccessAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: {
            Text(importSuccessMessage ?? NSLocalizedString("msg.hymn_imported_successfully", comment: "Default import success message"))
        }
        .alert("Export Successful", isPresented: $showingExportSuccessAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: {
            Text(exportSuccessMessage ?? "Hymns exported successfully")
        }
        .sheet(isPresented: $showingEdit) {
            Group {
                if let hymn = editHymn {
                    HymnEditView(
                        hymn: hymn, 
                        onSave: { savedHymn in
                            Task {
                                await saveHymn(savedHymn)
                            }
                        },
                        onCancel: {
                            // Clean up edit state on cancel
                            editHymn = nil
                        }
                    )
                } else if let hymn = newHymn {
                    HymnEditView(
                        hymn: hymn, 
                        onSave: { savedHymn in
                            Task {
                                await saveHymn(savedHymn)
                            }
                        },
                        onCancel: {
                            // Clean up new hymn state on cancel
                            newHymn = nil
                        }
                    )
                } else {
                    // Fallback: Create a new hymn if both editHymn and newHymn are nil
                    HymnEditView(
                        hymn: Hymn(title: ""), 
                        onSave: { savedHymn in
                            Task {
                                await saveHymn(savedHymn)
                            }
                        },
                        onCancel: {
                            // Clean up state on cancel
                            newHymn = nil
                        }
                    )
                    .onAppear {
                        print("WARNING: Sheet presented with no hymn - creating fallback new hymn")
                        newHymn = Hymn(title: "")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresenting) {
            if let hymnService = hymnService {
                DynamicPresenterView(
                    hymnService: hymnService,
                    selected: $selected,
                    onDismiss: {
                        presentedHymnIndex = nil
                        isPresenting = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingServiceManagement) {
            if let serviceService = serviceService, let hymnService = hymnService {
                ServiceManagementView(
                    serviceService: serviceService,
                    hymnService: hymnService
                )
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType.json, UTType.plainText],
            allowsMultipleSelection: true
        ) { result in
            handleImportResult(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: createExportDocument(),
            contentType: exportFormat == .json ? UTType.json : UTType.plainText,
            defaultFilename: createExportFilename()
        ) { result in
            handleExportResult(result)
        }
        .sheet(isPresented: $showingImportPreview) {
            if let preview = importPreview, let manager = importExportManager {
                ImportPreviewView(
                    preview: preview,
                    importManager: manager,
                    onComplete: { success in
                        showingImportPreview = false
                        if success {
                            // Show success alert with statistics
                            let totalHymns = preview.hymns.count + preview.duplicates.count
                            let newHymns = preview.hymns.count
                            let duplicates = totalHymns - newHymns
                            
                            var message = "Successfully imported \(newHymns) new hymn(s)"
                            if duplicates > 0 {
                                message += ", \(duplicates) duplicate(s) skipped"
                            }
                            message += " from \(preview.fileName)"
                            
                            importSuccessMessage = message
                            showingImportSuccessAlert = true
                            
                            Task {
                                await hymnService?.loadHymns()
                            }
                        }
                        importPreview = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingExportSelection) {
            if let hymnService = hymnService {
                ExportSelectionView(
                    hymns: hymnService.hymns,
                    selectedHymns: $selectedHymnsForExport,
                    exportFormat: $exportFormat,
                    onExport: { hymns, format in
                        exportHymns = hymns
                        exportFormat = format
                        showingExportSelection = false
                        showingExporter = true
                    }
                )
            }
        }
        .sheet(isPresented: $helpSystem.isHelpSheetPresented) {
            HelpSheetView(helpSystem: helpSystem)
        }
    }
    
    // MARK: - Layout Components
    
    @ViewBuilder
    private func iPadLayout(hymnService: HymnService, serviceService: ServiceService) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HymnListViewNew(
                hymnService: hymnService,
                serviceService: serviceService,
                selected: $selected,
                selectedHymnsForDelete: $selectedHymnsForDelete,
                isMultiSelectMode: $isMultiSelectMode,
                editHymn: $editHymn,
                showingEdit: $showingEdit,
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                newHymn: $newHymn,
                helpSystem: helpSystem,
                onPresent: onPresentHymn,
                onAddNew: addNewHymn,
                onEdit: editCurrentHymn
            )
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Services") {
                        print("Services button tapped")
                        showingServiceManagement = true
                    }
                    .id("services-button-\(toolbarRefreshTrigger)")
                    .onAppear {
                        print("Services button appeared in toolbar")
                    }
                    .onDisappear {
                        print("Services button disappeared from toolbar")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ExternalDisplayNavigationIndicator()
                        .id("external-display-\(toolbarRefreshTrigger)")
                        .onAppear {
                            print("External display indicator appeared in toolbar")
                        }
                        .onDisappear {
                            print("External display indicator disappeared from toolbar")
                        }
                }
            }
            .frame(minWidth: 320)
        } detail: {
            iPadDetailView(hymnService: hymnService, serviceService: serviceService)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private func iPhoneLayout(hymnService: HymnService, serviceService: ServiceService) -> some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Search & Song List
            HymnListViewNew(
                hymnService: hymnService,
                serviceService: serviceService,
                selected: $selected,
                selectedHymnsForDelete: $selectedHymnsForDelete,
                isMultiSelectMode: $isMultiSelectMode,
                editHymn: $editHymn,
                showingEdit: $showingEdit,
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                newHymn: $newHymn,
                helpSystem: helpSystem,
                onPresent: onPresentHymn,
                onAddNew: addNewHymn,
                onEdit: editCurrentHymn
            )
            .tabItem {
                Image(systemName: "music.note.list")
                Text("Library")
            }
            .tag(0)
            
            // Tab 2: Detail view with toolbar
            iPhoneDetailView(hymnService: hymnService, serviceService: serviceService)
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Song")
                }
                .tag(1)
            
            // Tab 3: Service Management
            ServiceManagementView(
                serviceService: serviceService,
                hymnService: hymnService
            )
            .tabItem {
                Image(systemName: "calendar")
                Text("Services")
            }
            .tag(2)
        }
    }
    
    @ViewBuilder
    private func iPadDetailView(hymnService: HymnService, serviceService: ServiceService) -> some View {
        VStack(spacing: 0) {
            // Toolbar at the top
            HymnToolbarViewNew(
                hymnService: hymnService,
                serviceService: serviceService,
                selected: $selected,
                selectedHymnsForDelete: $selectedHymnsForDelete,
                isMultiSelectMode: $isMultiSelectMode,
                showingEdit: $showingEdit,
                newHymn: $newHymn,
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                lyricsFontSize: $lyricsFontSize,
                showingImporter: $showingImporter,
                showingExportSelection: $showingExportSelection,
                selectedHymnsForExport: $selectedHymnsForExport,
                helpSystem: helpSystem,
                openWindow: openWindow,
                onPresent: onPresentHymn,
                onAddNew: addNewHymn,
                onEdit: editCurrentHymn
            )
            .padding(.top, 16)
            
            // Worship Session Controls (iPad only - prominent placement)
            if externalDisplayManager.state != .disconnected {
                WorshipSessionControls(serviceService: serviceService)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            
            // External Display Status Bar
            if externalDisplayManager.state != .disconnected {
                externalDisplayStatusView()
            }
            
            Divider()
            detailContentView()
        }
    }
    
    @ViewBuilder
    private func iPhoneDetailView(hymnService: HymnService, serviceService: ServiceService) -> some View {
        VStack(spacing: 0) {
            // Toolbar at the top
            HymnToolbarViewNew(
                hymnService: hymnService,
                serviceService: serviceService,
                selected: $selected,
                selectedHymnsForDelete: $selectedHymnsForDelete,
                isMultiSelectMode: $isMultiSelectMode,
                showingEdit: $showingEdit,
                newHymn: $newHymn,
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                lyricsFontSize: $lyricsFontSize,
                showingImporter: $showingImporter,
                showingExportSelection: $showingExportSelection,
                selectedHymnsForExport: $selectedHymnsForExport,
                helpSystem: helpSystem,
                openWindow: openWindow,
                onPresent: onPresentHymn,
                onAddNew: addNewHymn,
                onEdit: editCurrentHymn
            )
            .padding(.top, 16)
            
            // External Display Status Bar
            if externalDisplayManager.state != .disconnected {
                externalDisplayStatusView()
            }
            
            Divider()
            detailContentView()
        }
    }
    
    @ViewBuilder
    private func externalDisplayStatusView() -> some View {
        VStack(spacing: 0) {
            ExternalDisplayStatusBar(selectedHymn: selected)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private func detailContentView() -> some View {
        VStack {
            if isMultiSelectMode {
                MultiSelectDetailView(selectedHymnsForDelete: selectedHymnsForDelete)
            } else if let hymn = selected {
                DetailView(
                    hymn: hymn,
                    currentPresentationIndex: presentedHymnIndex,
                    isPresenting: isPresenting,
                    lyricsFontSize: $lyricsFontSize,
                    serviceService: serviceService,
                    hymnService: hymnService
                )
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Refresh services and external display when app becomes active
                print("App became active - refreshing services and external display state")
                Task {
                    await refreshServicesOnAppActivation()
                }
            }
        }
    }

    // MARK: - Service Initialization
    
    private func refreshServicesOnAppActivation() async {
        // Only refresh if services are already initialized
        guard servicesInitialized else { return }
        
        // Refresh hymn and service data
        await hymnService?.loadHymns()
        await serviceService?.loadServices()
        
        // Force toolbar UI refresh by toggling the refresh trigger
        await MainActor.run {
            toolbarRefreshTrigger.toggle()
            print("Services and toolbar refreshed after app activation - trigger: \(toolbarRefreshTrigger)")
        }
    }
    
    private func initializeServices() async {
        guard !servicesInitialized else { return }
        
        do {
            let hymnService = try await serviceFactory.createHymnService()
            let serviceService = try await serviceFactory.createServiceService()
            let operations = try await serviceFactory.createHymnOperations()
            
            await MainActor.run {
                self.hymnService = hymnService
                self.serviceService = serviceService
                
                // Connect ServiceService to WorshipSessionManager for validation
                self.worshipSessionManager.setServiceService(serviceService)
                
                self.importExportManager = ImportExportManager(
                    hymnService: hymnService,
                    serviceService: serviceService,
                    operations: operations
                )
                self.servicesInitialized = true
            }
        } catch {
            print("Failed to initialize services: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func onPresentHymn(_ hymn: Hymn) {
        if let index = hymnService?.hymns.firstIndex(where: { $0.id == hymn.id }) {
            presentedHymnIndex = index
            
            // If already presenting, just change the selected hymn
            if isPresenting {
                selected = hymn
                print("Switching to hymn: \(hymn.title) during presentation")
            } else {
                // Start new presentation
                selected = hymn // Ensure the hymn is selected before presenting
                isPresenting = true
                print("Starting presentation of hymn: \(hymn.title)")
            }
        }
    }
    
    private func addNewHymn() {
        // Prevent multiple rapid taps
        guard !showingEdit else {
            print("Edit sheet already showing, ignoring duplicate add request")
            return
        }
        
        print("Creating new hymn for editing")
        
        // Create new hymn and set state atomically
        let hymn = Hymn(title: "")
        newHymn = hymn
        editHymn = nil // Clear any lingering edit hymn state
        
        // Show sheet immediately - no async dispatch needed since we're already on main thread
        showingEdit = true
        print("Sheet presentation triggered with newHymn: \(newHymn?.id.uuidString ?? "nil")")
    }
    
    private func editCurrentHymn() {
        if let hymn = selected {
            editHymn = hymn
            newHymn = nil // Clear any lingering new hymn state
            showingEdit = true
        }
    }
    
    @State private var isSaving = false
    
    private func saveHymn(_ hymn: Hymn) async {
        guard let hymnService = hymnService else { return }
        
        // Prevent multiple simultaneous save operations
        guard !isSaving else {
            print("Save operation already in progress, ignoring duplicate call")
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        // Use proper ID-based detection instead of reference equality
        let isNewHymn = if let newHymn = newHymn {
            newHymn.id == hymn.id
        } else {
            false
        }
        
        print("Saving hymn: \(hymn.title), isNewHymn: \(isNewHymn), ID: \(hymn.id)")
        print("Hymn fields - Number: \(hymn.songNumber?.description ?? "nil"), Tags: \(hymn.tags?.description ?? "nil"), Author: \(hymn.author ?? "nil")")
        
        // Additional safety check for new hymns
        if isNewHymn {
            // Ensure this hymn doesn't already exist in the service
            if hymnService.hymns.contains(where: { $0.id == hymn.id }) {
                print("ERROR: Attempting to save new hymn that already exists in hymns array: \(hymn.title)")
                print("This suggests the hymn was incorrectly identified as 'new' when it should be 'edit'")
                print("Switching to update mode...")
                // Switch to update mode instead of failing
                let success = await hymnService.updateHymn(hymn)
                if success {
                    print("Successfully updated hymn via fallback: \(hymn.title)")
                    newHymn = nil
                    editHymn = nil
                    showingEdit = false
                } else {
                    print("Fallback update failed for: \(hymn.title)")
                }
                return
            }
        }
        
        let success = if isNewHymn {
            await hymnService.createHymn(hymn)
        } else {
            await hymnService.updateHymn(hymn)
        }
        
        if success {
            print("Save successful for: \(hymn.title)")
            // Proper state cleanup
            if isNewHymn {
                newHymn = nil
                selected = hymn // Set selection to the newly created hymn
            }
            editHymn = nil
            showingEdit = false
        } else {
            print("Save failed for: \(hymn.title)")
        }
    }
    
    private func deleteHymn(_ hymn: Hymn) async {
        guard let hymnService = hymnService else { return }
        
        let success = await hymnService.deleteHymn(hymn)
        if success {
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
    }
    
    private func deleteSelectedHymns() async {
        guard let hymnService = hymnService else { return }
        
        let hymnsToDelete = hymnService.hymns.filter { selectedHymnsForDelete.contains($0.id) }
        let deletedCount = await hymnService.deleteHymns(hymnsToDelete)
        
        if deletedCount > 0 {
            // Clear selection if any deleted hymns were selected
            for hymn in hymnsToDelete {
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
        }
        
        selectedHymnsForDelete.removeAll()
        isMultiSelectMode = false
    }
    
    // MARK: - Import/Export Actions
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        Task {
            switch result {
            case .success(let urls):
                guard let manager = importExportManager else { return }
                let importResult = await manager.importHymnsFromFiles(urls, importType: importType)
                
                await MainActor.run {
                    if let preview = importResult.preview {
                        importPreview = preview
                        showingImportPreview = true
                    } else if !importResult.errors.isEmpty {
                        // Show import error alert
                        importError = convertToImportExportError(ImportResultError(messages: importResult.errors))
                        showingImportErrorAlert = true
                    }
                }
                
            case .failure(let error):
                await MainActor.run {
                    importError = ImportExportError.unexpectedError(error.localizedDescription)
                    showingImportErrorAlert = true
                }
            }
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        Task {
            switch result {
            case .success(let url):
                guard let manager = importExportManager else { return }
                let success = await manager.exportHymns(exportHymns, to: url, format: exportFormat)
                
                await MainActor.run {
                    if success {
                        let count = exportHymns.count
                        let hymnWord = count == 1 ? NSLocalizedString("service.hymn_single", comment: "hymn") : NSLocalizedString("service.hymn_plural", comment: "hymns")
                        exportSuccessMessage = "Successfully exported \(count) \(hymnWord) to \(url.lastPathComponent)"
                        showingExportSuccessAlert = true
                    } else {
                        importError = ImportExportError.unexpectedError("Failed to export hymns")
                        showingImportErrorAlert = true
                    }
                }
                
            case .failure(let error):
                await MainActor.run {
                    importError = ImportExportError.permissionDenied(error.localizedDescription)
                    showingImportErrorAlert = true
                }
            }
        }
    }
    
    // Helper error type for import results
    private struct ImportResultError: Error {
        let messages: [String]
        
        var localizedDescription: String {
            messages.joined(separator: "\n")
        }
    }
    
    // Helper function to convert error types to ImportExportError
    private func convertToImportExportError(_ error: Error) -> ImportExportError {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("file not found") || errorString.contains("no such file") {
            return ImportExportError.fileNotFound(error.localizedDescription)
        } else if errorString.contains("permission") || errorString.contains("access") {
            return ImportExportError.permissionDenied(error.localizedDescription)
        } else if errorString.contains("empty") {
            return ImportExportError.emptyFile(error.localizedDescription)
        } else if errorString.contains("format") || errorString.contains("invalid") {
            return ImportExportError.invalidFileFormat(error.localizedDescription)
        } else if errorString.contains("json") {
            return ImportExportError.invalidJSON(error.localizedDescription)
        } else if errorString.contains("title") {
            return ImportExportError.hymnTitleMissing(error.localizedDescription)
        } else if errorString.contains("corrupt") {
            return ImportExportError.fileCorrupted(error.localizedDescription)
        } else {
            return ImportExportError.unexpectedError(error.localizedDescription)
        }
    }
    
    private func createExportDocument() -> HymnExportDocument? {
        return HymnExportDocument(hymns: exportHymns, format: exportFormat)
    }
    
    private func createExportFilename() -> String {
        let count = exportHymns.count
        let suffix = count == 1 ? exportHymns.first?.title ?? "hymn" : "\(count)_hymns"
        return "\(suffix).\(exportFormat.fileExtension)"
    }
}



// MARK: - Loading View for Services

struct LoadingServicesView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Services...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - New UI Components (Simplified implementations)

struct HymnListViewNew: View {
    @ObservedObject var hymnService: HymnService
    @ObservedObject var serviceService: ServiceService
    
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var editHymn: Hymn?
    @Binding var showingEdit: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    @Binding var newHymn: Hymn?
    
    @ObservedObject var helpSystem: HelpSystem
    
    let onPresent: (Hymn) -> Void
    let onAddNew: () -> Void
    let onEdit: () -> Void
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .title
    @State private var isServiceBarCollapsed = false
    
    // Service management alerts
    @State private var showingClearAllConfirmation = false
    @State private var showingCompleteServiceConfirmation = false
    @State private var showingServiceCompletedSuccess = false
    
    // Service reorder mode
    @State private var isServiceReorderMode = false
    
    enum SortOption: CaseIterable, Identifiable {
        case title
        case number
        case key
        case service
        
        var id: String { self.rawValue }
        
        var rawValue: String {
            switch self {
            case .title:
                return NSLocalizedString("sort.title", comment: "Title sort option")
            case .number:
                return NSLocalizedString("sort.number", comment: "Number sort option")
            case .key:
                return NSLocalizedString("sort.key", comment: "Key sort option")
            case .service:
                return NSLocalizedString("sort.service", comment: "Service sort option")
            }
        }
    }
    
    /// Enhanced search function that searches across all hymn fields
    /// Optimized for performance with pre-computed normalized values
    private func searchMatches(hymn: Hymn, query: String) -> Bool {
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Early return for empty query
        if searchQuery.isEmpty { return true }
        
        // Search in normalized title (pre-computed for performance)
        if hymn.normalizedTitle.contains(searchQuery) {
            return true
        }
        
        // Search in song number if present (exact match or partial)
        if let number = hymn.songNumber {
            let numberString = String(number)
            if numberString.contains(searchQuery) || searchQuery.contains(numberString) {
                return true
            }
        }
        
        // Search in lyrics if present
        if let lyrics = hymn.lyrics,
           !lyrics.isEmpty,
           lyrics.lowercased().contains(searchQuery) {
            return true
        }
        
        // Search in author if present
        if let author = hymn.author,
           !author.isEmpty,
           author.lowercased().contains(searchQuery) {
            return true
        }
        
        // Search in tags if present
        if let tags = hymn.tags,
           !tags.isEmpty,
           tags.contains(where: { $0.lowercased().contains(searchQuery) }) {
            return true
        }
        
        // Search in notes if present
        if let notes = hymn.notes,
           !notes.isEmpty,
           notes.lowercased().contains(searchQuery) {
            return true
        }
        
        // Search in musical key if present
        if let musicalKey = hymn.musicalKey,
           !musicalKey.isEmpty,
           musicalKey.lowercased().contains(searchQuery) {
            return true
        }
        
        // Search in copyright if present
        if let copyright = hymn.copyright,
           !copyright.isEmpty,
           copyright.lowercased().contains(searchQuery) {
            return true
        }
        
        return false
    }
    
    var filteredHymns: [Hymn] {
        // First determine the base hymn list based on sort option
        let baseHymns: [Hymn]
        if sortOption == .service {
            // Service filter mode - show only service hymns
            if let activeService = serviceService.activeService {
                let serviceHymnIds = serviceService.serviceHymns
                    .filter { $0.serviceId == activeService.id }
                    .map { $0.hymnId }
                baseHymns = hymnService.hymns.filter { hymn in
                    serviceHymnIds.contains(hymn.id)
                }
            } else {
                baseHymns = [] // No active service, show empty list
            }
        } else {
            // Regular mode - show all hymns
            baseHymns = hymnService.hymns
        }
        
        // Then apply search filter
        let filtered: [Hymn]
        if searchText.isEmpty {
            filtered = baseHymns
        } else {
            filtered = baseHymns.filter { hymn in
                searchMatches(hymn: hymn, query: searchText)
            }
        }
        
        // Sort based on selected option
        switch sortOption {
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .number:
            return filtered.sorted {
                ($0.songNumber ?? Int.max) < ($1.songNumber ?? Int.max)
            }
        case .key:
            return filtered.sorted {
                ($0.musicalKey ?? "").localizedCaseInsensitiveCompare($1.musicalKey ?? "") == .orderedAscending
            }
        case .service:
            // Service hymns ordered by service order, then by title
            if let activeService = serviceService.activeService {
                let serviceHymns = serviceService.serviceHymns
                    .filter { $0.serviceId == activeService.id }
                    .sorted { $0.order < $1.order }
                
                // Create ordered list based on service order
                var ordered: [Hymn] = []
                for serviceHymn in serviceHymns {
                    if let hymn = filtered.first(where: { $0.id == serviceHymn.hymnId }) {
                        ordered.append(hymn)
                    }
                }
                return ordered
            } else {
                return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }
        }
    }
    
    // MARK: - Service Position Helpers
    
    /// Get the position of a hymn in the active service (1-based for display)
    private func getHymnPositionInService(_ hymn: Hymn) -> Int? {
        guard let activeService = serviceService.activeService else { return nil }
        
        let serviceHymns = serviceService.serviceHymns
            .filter { $0.serviceId == activeService.id }
            .sorted { $0.order < $1.order }
        
        if let index = serviceHymns.firstIndex(where: { $0.hymnId == hymn.id }) {
            return index + 1 // Convert to 1-based for display
        }
        
        return nil
    }
    
    // Helper computed property for service management bar
    private var activeServiceHymnCount: Int {
        guard let activeService = serviceService.activeService else { return 0 }
        return serviceService.serviceHymns
            .filter { $0.serviceId == activeService.id }
            .count
    }
    
    var body: some View {
        VStack {
            // Service Management Bar (when active service exists)
            if serviceService.activeService != nil {
                ServiceManagementBar(
                    activeService: serviceService.activeService,
                    hymnCount: activeServiceHymnCount,
                    isCollapsed: $isServiceBarCollapsed,
                    onClearAll: clearAllServiceHymns,
                    onCompleteService: completeActiveService,
                    onReorderToggle: toggleServiceReorderMode,
                    onManageToggle: toggleServiceManagement
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Divider()
            }
            
            // Multi-select mode toolbar (only shown when in selection mode)
            if isMultiSelectMode {
                HStack {
                    // Multi-select mode buttons
                    HStack(spacing: 12) {
                        if selectedHymnsForDelete.count == filteredHymns.count && !filteredHymns.isEmpty {
                            Button(NSLocalizedString("btn.deselect_all", comment: "Deselect All")) {
                                selectedHymnsForDelete.removeAll()
                            }
                            .foregroundColor(.accentColor)
                        } else if !filteredHymns.isEmpty {
                            Button("\(NSLocalizedString("btn.select_all", comment: "Select All")) (\(filteredHymns.count))") {
                                selectedHymnsForDelete = Set(filteredHymns.map { $0.id })
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        isMultiSelectMode = false
                        selectedHymnsForDelete.removeAll()
                    }
                    
                    if !selectedHymnsForDelete.isEmpty {
                        Button("Delete Selected (\(selectedHymnsForDelete.count))") {
                            showingBatchDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding()
            }
            
            // Sort options picker and reorder controls (only show when not in multi-select mode)
            if !isMultiSelectMode {
                VStack(spacing: 8) {
                    Picker(NSLocalizedString("sort.by", comment: "Sort by picker"), selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option as SortOption)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(isServiceReorderMode)
                    .opacity(isServiceReorderMode ? 0.5 : 1.0)
                    .onChange(of: sortOption) { _, newValue in
                        // Exit reorder mode when switching away from service sort
                        if newValue != .service && isServiceReorderMode {
                            isServiceReorderMode = false
                        }
                    }
                    
                    // Show reorder button when service sort is active and has hymns
                    if sortOption == .service && activeServiceHymnCount > 0 {
                        HStack {
                            Button(action: toggleServiceReorderMode) {
                                HStack(spacing: 6) {
                                    Image(systemName: isServiceReorderMode ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                                        .foregroundColor(isServiceReorderMode ? .orange : .accentColor)
                                    Text(isServiceReorderMode ? "Exit Reorder" : "Reorder Hymns")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(isServiceReorderMode ? .orange : .accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                
                Divider()
            }
            
            // Error display
            if let error = hymnService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        hymnService.clearError()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            
            // Content
            if hymnService.isLoading {
                VStack {
                    ProgressView()
                    Text("Loading hymns...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hymnService.hymns.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Hymns")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Use the toolbar to add your first hymn")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        Button("Add Hymn", action: onAddNew)
                            .buttonStyle(.borderedProminent)
                        
                        Button("Get Help") {
                            helpSystem.showHelp(for: .addingFirstHymn)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredHymns) { hymn in
                        HymnRowView(
                            hymn: hymn,
                            isSelected: selected?.id == hymn.id,
                            isMarkedForDelete: selectedHymnsForDelete.contains(hymn.id),
                            isMultiSelectMode: isMultiSelectMode,
                            isReorderMode: isServiceReorderMode,
                            servicePosition: getHymnPositionInService(hymn),
                            showServicePosition: sortOption == .service,
                            onTap: {
                                // Disable interactions during reorder mode
                                guard !isServiceReorderMode else { return }
                                
                                if isMultiSelectMode {
                                    if selectedHymnsForDelete.contains(hymn.id) {
                                        selectedHymnsForDelete.remove(hymn.id)
                                    } else {
                                        selectedHymnsForDelete.insert(hymn.id)
                                    }
                                } else {
                                    selected = hymn
                                }
                            },
                            onEdit: {
                                // Disable edit during reorder mode
                                guard !isServiceReorderMode else { return }
                                selected = hymn
                                editHymn = hymn
                                showingEdit = true
                            },
                            onDelete: {
                                // Disable delete during reorder mode
                                guard !isServiceReorderMode else { return }
                                hymnToDelete = hymn
                                showingDeleteConfirmation = true
                            },
                            onPresent: { 
                                // Disable present during reorder mode
                                guard !isServiceReorderMode else { return }
                                onPresent(hymn) 
                            },
                            onLongPress: {
                                // Disable long press selection during reorder mode
                                guard !isServiceReorderMode else { return }
                                
                                // Enter selection mode on long press
                                if !isMultiSelectMode {
                                    // Provide haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    isMultiSelectMode = true
                                    selectedHymnsForDelete.insert(hymn.id)
                                }
                            }
                        )
                    }
                    .onMove(perform: (isServiceReorderMode && sortOption == .service) ? moveServiceHymns : nil)
                }
                .environment(\.editMode, (isServiceReorderMode && sortOption == .service) ? .constant(.active) : .constant(.inactive))
                .searchable(text: $searchText, prompt: "Search hymns...")
                // Note: Don't disable the entire list in reorder mode - this prevents drag handles from working
                
                // Show reorder instructions when in reorder mode
                if isServiceReorderMode && sortOption == .service {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.orange)
                        Text("Drag hymns to reorder them in the service")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }
            }
        }
        .task {
            if hymnService.hymns.isEmpty && !hymnService.isLoading {
                await hymnService.loadHymns()
            }
        }
        // Service Confirmation Alerts
        .alert(NSLocalizedString("service.clear_all_title", comment: "Clear all hymns title"), isPresented: $showingClearAllConfirmation) {
            Button(NSLocalizedString("btn.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("service.clear_all", comment: "Clear all"), role: .destructive) {
                Task {
                    guard let activeService = serviceService.activeService else { return }
                    let success = await serviceService.clearAllHymnsFromService(activeService.id)
                    if success {
                        print("Successfully cleared all hymns from service")
                    } else {
                        print("Failed to clear hymns from service")
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("service.clear_all_message", comment: "Clear all confirmation message"))
        }
        .alert(NSLocalizedString("service.complete_title", comment: "Complete service title"), isPresented: $showingCompleteServiceConfirmation) {
            Button(NSLocalizedString("btn.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("service.complete", comment: "Complete"), role: .destructive) {
                Task {
                    guard let activeService = serviceService.activeService else { return }
                    let success = await serviceService.completeService(activeService.id)
                    if success {
                        showingServiceCompletedSuccess = true
                    } else {
                        print("Failed to complete service")
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("service.complete_message", comment: "Complete service confirmation message"))
        }
        .alert(NSLocalizedString("service.completed_success_title", comment: "Service completed success title"), isPresented: $showingServiceCompletedSuccess) {
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: {
            Text(NSLocalizedString("service.completed_success_message", comment: "Service completed success message"))
        }
    }
    
    // MARK: - Service Management Actions
    
    private func clearAllServiceHymns() {
        showingClearAllConfirmation = true
    }
    
    private func completeActiveService() {
        showingCompleteServiceConfirmation = true
    }
    
    
    private func toggleServiceReorderMode() {
        // Switch to service sort when entering reorder mode
        sortOption = .service
        isServiceReorderMode.toggle()
        print("Service reorder mode toggled: \(isServiceReorderMode)")
    }
    
    private func toggleServiceManagement() {
        print("Service management mode toggled")
    }
    
    // MARK: - Service Reordering
    
    private func moveServiceHymns(from source: IndexSet, to destination: Int) {
        guard let activeService = serviceService.activeService,
              let sourceIndex = source.first,
              sortOption == .service else { return }
        
        // Get the current ordered list of hymns for this service
        let serviceHymns = serviceService.serviceHymns
            .filter { $0.serviceId == activeService.id }
            .sorted { $0.order < $1.order }
        
        // Validate indices
        guard sourceIndex < serviceHymns.count,
              destination <= serviceHymns.count else {
            print("Invalid reorder indices: source \(sourceIndex), destination \(destination)")
            return
        }
        
        // Adjust destination if moving down
        let adjustedDestination = destination > sourceIndex ? destination - 1 : destination
        
        // Create reordered array of hymn IDs
        var reorderedHymnIds = serviceHymns.map { $0.hymnId }
        let movedHymnId = reorderedHymnIds.remove(at: sourceIndex)
        reorderedHymnIds.insert(movedHymnId, at: adjustedDestination)
        
        // Apply reordering
        Task {
            let success = await serviceService.reorderServiceHymns(serviceId: activeService.id, hymnIds: reorderedHymnIds)
            if success {
                print("Successfully reordered service hymns")
                
                // Provide haptic feedback for successful reorder
                await MainActor.run {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            } else {
                print("Failed to reorder service hymns")
                
                // Provide error haptic feedback
                await MainActor.run {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}


struct HymnRowView: View {
    let hymn: Hymn
    let isSelected: Bool
    let isMarkedForDelete: Bool
    let isMultiSelectMode: Bool
    let isReorderMode: Bool
    let servicePosition: Int?
    let showServicePosition: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPresent: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        HStack {
            if isMultiSelectMode {
                Button(action: onTap) {
                    Image(systemName: isMarkedForDelete ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isMarkedForDelete ? .accentColor : .secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hymn.title.isEmpty ? "Untitled Hymn" : hymn.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let author = hymn.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let key = hymn.musicalKey, !key.isEmpty {
                    Text("Key: \(key)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Service position indicator
            if showServicePosition, let position = servicePosition {
                Text("#\(position)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            
            if !isMultiSelectMode && !isReorderMode {
                Menu {
                    Button("Present", action: onPresent)
                    Button("Edit", action: onEdit)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Show reorder indicator when in reorder mode
            if isReorderMode {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.1) : 
            isReorderMode ? Color.orange.opacity(0.05) : nil
        )
    }
}

struct HymnToolbarViewNew: View {
    @ObservedObject var hymnService: HymnService
    @ObservedObject var serviceService: ServiceService
    
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var showingEdit: Bool
    @Binding var newHymn: Hymn?
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    @Binding var lyricsFontSize: CGFloat
    
    // Import/Export bindings
    @Binding var showingImporter: Bool
    @Binding var showingExportSelection: Bool
    @Binding var selectedHymnsForExport: Set<UUID>
    
    // Help system
    @ObservedObject var helpSystem: HelpSystem
    
    let openWindow: OpenWindowAction
    let onPresent: (Hymn) -> Void
    let onAddNew: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Primary action buttons - larger icons with labels
            HStack(spacing: 20) {
                // Present Button (most important)
                Button(action: {
                    if let hymn = selected {
                        onPresent(hymn)
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("Present")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .disabled(selected == nil)
                .help("Present selected hymn")
                
                // Add Button
                Button(action: onAddNew) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("Add")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .help("Add new hymn")
                
                // Edit Button
                Button(action: onEdit) {
                    VStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundColor(selected == nil ? .gray : .orange)
                        Text("Edit")
                            .font(.caption)
                            .foregroundColor(selected == nil ? .gray : .primary)
                    }
                }
                .disabled(selected == nil)
                .help("Edit selected hymn")
                
                // Delete Button
                Button(action: {
                    if isMultiSelectMode {
                        if !selectedHymnsForDelete.isEmpty {
                            showingBatchDeleteConfirmation = true
                        }
                    } else if let hymn = selected {
                        hymnToDelete = hymn
                        showingDeleteConfirmation = true
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Delete")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .disabled(isMultiSelectMode ? selectedHymnsForDelete.isEmpty : selected == nil)
                .help(isMultiSelectMode ? "Delete selected hymns" : "Delete selected hymn")
            }
            
            Spacer()
            
            // Secondary actions with labels
            HStack(spacing: 16) {
                // Import Button
                Button(action: {
                    showingImporter = true
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                        Text("Import")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .help("Import hymns from files")
                
                // Export Menu with label
                Menu {
                    Button("Export Selected") { 
                        if let hymn = selected {
                            selectedHymnsForExport = [hymn.id]
                            showingExportSelection = true
                        }
                    }
                    .disabled(selected == nil)
                    
                    Button("Export Multiple") { 
                        showingExportSelection = true
                    }
                    .disabled(hymnService.hymns.isEmpty)
                    
                    Button("Export All") { 
                        selectedHymnsForExport = Set(hymnService.hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymnService.hymns.isEmpty)
                    
                    Divider()
                    
                    Button("Export Help") {
                        helpSystem.showHelp(for: .exportingHymns)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("Export")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .help("Export hymns to files")
                
                // External Display Button with label
                Button(action: {
                    switch externalDisplayManager.state {
                    case .disconnected:
                        break
                    case .connected:
                        if let hymn = selected {
                            do {
                                try externalDisplayManager.startPresentation(hymn: hymn)
                            } catch {
                                print("External display error: \(error)")
                            }
                        }
                    case .presenting:
                        externalDisplayManager.stopPresentation()
                    case .worshipMode:
                        if let hymn = selected {
                            Task {
                                do {
                                    try await externalDisplayManager.presentHymnInWorshipMode(hymn)
                                } catch {
                                    print("Worship hymn presentation error: \(error)")
                                }
                            }
                        }
                    case .worshipPresenting:
                        Task {
                            await externalDisplayManager.stopHymnInWorshipMode()
                        }
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: externalDisplayIconName)
                            .font(.title)
                            .foregroundColor(externalDisplayColor)
                        Text(externalDisplayText)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .disabled(externalDisplayManager.state == .disconnected || 
                         (externalDisplayManager.state == .connected && selected == nil))
                .help(externalDisplayHelpText)
                
                // Worship Session Control
                CompactWorshipSessionControl(serviceService: serviceService)
                
                // Font Size Controls with label
                Menu {
                    VStack(spacing: 12) {
                        Text("Font Size: \(Int(lyricsFontSize))")
                            .font(.headline)
                        
                        Slider(value: $lyricsFontSize, in: 12...32, step: 1)
                    }
                    .padding()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "textformat.size")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Font Size")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
                .help("Adjust font size")
                
                // Help Button (iPad only)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    HelpButton(
                        helpSystem: helpSystem,
                        context: getHelpContext()
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // Helper computed properties for external display
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    
    private var externalDisplayIconName: String {
        switch externalDisplayManager.state {
        case .disconnected: return "tv.slash"
        case .connected: return "tv"
        case .presenting: return "tv.fill"
        case .worshipMode: return "tv.fill"
        case .worshipPresenting: return "tv.fill"
        }
    }
    
    private var externalDisplayColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return .gray
        case .connected: return .green
        case .presenting: return .orange
        case .worshipMode: return .purple
        case .worshipPresenting: return .orange
        }
    }
    
    private var externalDisplayText: String {
        switch externalDisplayManager.state {
        case .disconnected: return "No Display"
        case .connected: return "External"
        case .presenting: return "Stop External"
        case .worshipMode: return "Worship"
        case .worshipPresenting: return "Stop Hymn"
        }
    }
    
    private var externalDisplayHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected: return "No external display"
        case .connected: return "Present to external display"
        case .presenting: return "Stop external presentation"
        case .worshipMode: return "Present hymn in worship session"
        case .worshipPresenting: return "Stop hymn (return to worship background)"
        }
    }
    
    // Helper method to determine contextual help
    private func getHelpContext() -> HelpContext? {
        if isMultiSelectMode {
            return .multiSelectMode
        } else if selected != nil {
            return .hymnSelected
        } else if hymnService.hymns.isEmpty {
            return .emptyHymnList
        } else if externalDisplayManager.state != .disconnected {
            return .externalDisplay
        } else if serviceService.activeService != nil {
            return .serviceManagement
        }
        return nil
    }
}


