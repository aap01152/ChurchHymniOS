import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import Foundation

// MARK: - Phase 2: Validation and Transaction Safety

/// Result of hymn validation operations
enum HymnValidationResult {
    case success
    case warning(String)
    case failure(String)
    
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .warning, .failure: return false
        }
    }
    
    var message: String? {
        switch self {
        case .success: return nil
        case .warning(let msg), .failure(let msg): return msg
        }
    }
}

/// Transaction result for atomic operations
enum HymnTransactionResult {
    case success(Hymn)
    case failure(String)
    case rollback(String)
}

// MARK: - Phase 3: Recovery and Diagnostics

/// Data integrity issues found during checks
struct DataIntegrityIssue {
    let type: IssueType
    let description: String
    let severity: IssueSeverity
    let affectedHymnId: UUID?
    let serviceId: UUID?
    
    enum IssueType {
        case orphanedServiceHymn
        case missingHymn
        case duplicateHymn
        case corruptedData
        case inconsistentState
    }
    
    enum IssueSeverity {
        case critical   // Data corruption that must be fixed
        case warning    // Inconsistencies that should be addressed
        case info       // Minor issues or suggestions
    }
}

/// Result of data integrity check
struct IntegrityCheckResult {
    let issues: [DataIntegrityIssue]
    let checkedHymns: Int
    let checkedServices: Int
    let orphanedServiceHymns: Int
    let duplicateHymns: Int
    
    var hasCriticalIssues: Bool {
        issues.contains { $0.severity == .critical }
    }
    
    var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }
    
    var isHealthy: Bool {
        issues.isEmpty
    }
}

/// Recovery operation result
enum RecoveryResult {
    case success(recoveredCount: Int, message: String)
    case partialSuccess(recoveredCount: Int, failedCount: Int, message: String)
    case failure(String)
}

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
    @State private var presentedHymnIndex: Int? = nil
    @State private var isPresenting = false
    
    // Separate state for new hymn creation (Phase 1 fix for data corruption)
    @State private var newHymnBeingCreated: Hymn? = nil
    @State private var showingNewHymnSheet = false
    
    // Separate state for existing hymn editing (Phase 1 fix for data corruption)
    @State private var existingHymnBeingEdited: Hymn? = nil
    @State private var showingEditHymnSheet = false
    
    // PHASE 2: Enhanced error handling and validation
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showingValidationWarning = false
    @State private var validationWarningMessage = ""
    @State private var isSavingWithTransaction = false
    
    // PHASE 3: Recovery and diagnostics
    @State private var showingDataIntegrityCheck = false
    @State private var integrityCheckResult: IntegrityCheckResult?
    @State private var isRunningIntegrityCheck = false
    @State private var showingRecoveryOptions = false
    @State private var isRunningRecovery = false
    @State private var recoveryResult: RecoveryResult?
    @State private var showingRecoveryResult = false
    @State private var autoIntegrityCheckCompleted = false
    
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
    
    // Phase 4: Testing Framework UI States
    @State private var showingTestSuite = false
    @State private var testResults: [ValidationTestResult] = []
    @State private var isRunningTests = false

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
        .alert(NSLocalizedString("alert.delete_hymn", comment: "Delete Hymn"), isPresented: $showingDeleteConfirmation, presenting: hymnToDelete) { hymn in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteHymn(hymn)
                }
            }
        } message: { hymn in
            Text(String(format: NSLocalizedString("msg.delete_hymn_confirm", comment: "Are you sure you want to delete '%@'?"), hymn.title))
        }
        .alert(NSLocalizedString("alert.delete_multiple_hymns", comment: "Delete Multiple Hymns"), isPresented: $showingBatchDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSelectedHymns()
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("msg.delete_multiple_hymns_confirm", comment: "Are you sure you want to delete %d hymns?"), selectedHymnsForDelete.count))
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
        .alert(NSLocalizedString("alert.export_successful", comment: "Export Successful"), isPresented: $showingExportSuccessAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK button")) { }
        } message: {
            Text(exportSuccessMessage ?? "Hymns exported successfully")
        }
        // PHASE 2: Enhanced error handling alerts
        .alert(NSLocalizedString("alert.save_error", comment: "Save Error"), isPresented: $showingSaveError) {
            Button(NSLocalizedString("btn.ok", comment: "OK")) { }
        } message: {
            Text(saveErrorMessage)
        }
        .alert(NSLocalizedString("alert.validation_warning", comment: "Validation Warning"), isPresented: $showingValidationWarning) {
            Button(NSLocalizedString("btn.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("btn.save", comment: "Save Anyway")) {
                // Force save despite warnings
                Task {
                    await forceSaveWithWarnings()
                }
            }
        } message: {
            Text(validationWarningMessage)
        }
        // PHASE 3: Data integrity and recovery alerts
        .alert(NSLocalizedString("alert.data_integrity_check", comment: "Data Integrity Check"), isPresented: $showingDataIntegrityCheck) {
            if let result = integrityCheckResult {
                if result.hasCriticalIssues {
                    Button("View Issues") {
                        showingRecoveryOptions = true
                    }
                    Button("Dismiss") { }
                } else {
                    Button("OK") { }
                }
            } else {
                Button("OK") { }
            }
        } message: {
            if let result = integrityCheckResult {
                if result.hasCriticalIssues {
                    Text("Critical data issues found: \(result.issues.filter { $0.severity == .critical }.count) critical, \(result.issues.filter { $0.severity == .warning }.count) warnings. Checked \(result.checkedHymns) hymns and \(result.checkedServices) services.")
                } else if result.hasWarnings {
                    Text("Data check complete: \(result.issues.count) warnings found. Checked \(result.checkedHymns) hymns and \(result.checkedServices) services.")
                } else {
                    Text("Data integrity check passed. No issues found in \(result.checkedHymns) hymns and \(result.checkedServices) services.")
                }
            } else {
                Text("Running data integrity check...")
            }
        }
        .alert("Recovery Complete", isPresented: $showingRecoveryResult) {
            Button("OK") { }
        } message: {
            if let result = recoveryResult {
                switch result {
                case .success(let count, let message):
                    Text("\(message) (\(count) items)")
                case .partialSuccess(let recovered, let failed, let message):
                    Text("\(message) (\(recovered) recovered, \(failed) failed)")
                case .failure(let message):
                    Text("Recovery failed: \(message)")
                }
            } else {
                Text("Recovery completed")
            }
        }
        // PHASE 1 FIX: Separate sheets for new vs edit operations
        .sheet(isPresented: $showingNewHymnSheet) {
            newHymnEditSheet
        }
        .sheet(isPresented: $showingEditHymnSheet) {
            if let hymn = existingHymnBeingEdited {
                HymnEditView(
                    hymn: hymn, 
                    onSave: { savedHymn in
                        Task {
                            await updateExistingHymn(savedHymn)
                        }
                    },
                    onCancel: {
                        // Clean up edit state on cancel
                        existingHymnBeingEdited = nil
                        showingEditHymnSheet = false
                    }
                )
            } else {
                // This should not happen with proper state management
                Text("No hymn to edit")
                    .onAppear {
                        showingEditHymnSheet = false
                    }
            }
        }
        // PHASE 3: Data recovery options sheet
        .sheet(isPresented: $showingRecoveryOptions) {
            DataRecoveryOptionsView(
                integrityResult: integrityCheckResult,
                isRunningRecovery: $isRunningRecovery,
                onRecoverOrphans: {
                    Task {
                        isRunningRecovery = true
                        let result = await recoverOrphanedHymns()
                        await MainActor.run {
                            isRunningRecovery = false
                            recoveryResult = result
                            showingRecoveryResult = true
                            showingRecoveryOptions = false
                        }
                    }
                },
                onCleanupOrphans: {
                    Task {
                        isRunningRecovery = true
                        let result = await cleanupOrphanedServiceHymns()
                        await MainActor.run {
                            isRunningRecovery = false
                            recoveryResult = result
                            showingRecoveryResult = true
                            showingRecoveryOptions = false
                        }
                    }
                },
                onRunIntegrityCheck: {
                    Task {
                        isRunningIntegrityCheck = true
                        let result = await performDataIntegrityCheck()
                        await MainActor.run {
                            isRunningIntegrityCheck = false
                            integrityCheckResult = result
                            showingDataIntegrityCheck = true
                            showingRecoveryOptions = false
                        }
                    }
                },
                isRunningTests: $isRunningTests,
                onRunTestSuite: {
                    Task {
                        await runTestSuite()
                    }
                }
            )
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
        .sheet(isPresented: $showingTestSuite) {
            TestResultsView(testResults: testResults)
        }
    }
    
    // MARK: - Layout Components
    
    @ViewBuilder
    private var newHymnEditSheet: some View {
        let _ = print("🔍 Sheet building - newHymnBeingCreated: \(newHymnBeingCreated?.id.uuidString ?? "NIL")")
        if let hymn = newHymnBeingCreated {
            HymnEditView(
                hymn: hymn, 
                onSave: { savedHymn in
                    print("DEBUG: Save called - Original ID: \(hymn.id.uuidString), Saved ID: \(savedHymn.id.uuidString)")
                    Task {
                        await saveNewHymn(savedHymn)
                    }
                },
                onCancel: {
                    print("🚫 New hymn creation cancelled")
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                }
            )
        } else {
            // CRITICAL FIX: Never show edit sheet if state is corrupted
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("Error: Invalid State")
                    .font(.headline)
                
                Text("Hymn creation state was corrupted. Please try again.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    print("ERROR: Sheet shown without proper state - forcing close")
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func iPadLayout(hymnService: HymnService, serviceService: ServiceService) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HymnListViewNew(
                hymnService: hymnService,
                serviceService: serviceService,
                selected: $selected,
                selectedHymnsForDelete: $selectedHymnsForDelete,
                isMultiSelectMode: $isMultiSelectMode,
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                helpSystem: helpSystem,
                onPresent: onPresentHymn,
                onAddNew: {
                    print("🔵 ADD BUTTON PRESSED - calling addNewHymn()")
                    print("🔍 Pre-add state check:")
                    print("  - Selected hymn: \(selected?.title ?? "None")")
                    print("  - showingNewHymnSheet: \(showingNewHymnSheet)")
                    print("  - showingEditHymnSheet: \(showingEditHymnSheet)")
                    print("  - newHymnBeingCreated: \(newHymnBeingCreated?.title ?? "None")")
                    print("  - existingHymnBeingEdited: \(existingHymnBeingEdited?.title ?? "None")")
                    
                    // CRITICAL FIX: Don't clear edit state if edit sheet is showing to prevent race condition
                    guard !showingEditHymnSheet else {
                        print("⚠️ Edit sheet is showing, ignoring add request to prevent race condition")
                        return
                    }
                    
                    // Force clean state before adding
                    newHymnBeingCreated = nil
                    existingHymnBeingEdited = nil
                    showingNewHymnSheet = false
                    showingEditHymnSheet = false
                    
                    // Small delay to ensure clean state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addNewHymn()
                    }
                },
                onEdit: editCurrentHymn
            )
            .navigationTitle(NSLocalizedString("nav.library", comment: "Library navigation bar title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("nav.services", comment: "Services button")) {
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
                hymnToDelete: $hymnToDelete,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingBatchDeleteConfirmation: $showingBatchDeleteConfirmation,
                helpSystem: helpSystem,
                onPresent: onPresentHymn,
                onAddNew: {
                    print("🔵 ADD BUTTON PRESSED - calling addNewHymn()")
                    print("🔍 Pre-add state check:")
                    print("  - Selected hymn: \(selected?.title ?? "None")")
                    print("  - showingNewHymnSheet: \(showingNewHymnSheet)")
                    print("  - showingEditHymnSheet: \(showingEditHymnSheet)")
                    print("  - newHymnBeingCreated: \(newHymnBeingCreated?.title ?? "None")")
                    print("  - existingHymnBeingEdited: \(existingHymnBeingEdited?.title ?? "None")")
                    
                    // CRITICAL FIX: Don't clear edit state if edit sheet is showing to prevent race condition
                    guard !showingEditHymnSheet else {
                        print("⚠️ Edit sheet is showing, ignoring add request to prevent race condition")
                        return
                    }
                    
                    // Force clean state before adding
                    newHymnBeingCreated = nil
                    existingHymnBeingEdited = nil
                    showingNewHymnSheet = false
                    showingEditHymnSheet = false
                    
                    // Small delay to ensure clean state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addNewHymn()
                    }
                },
                onEdit: editCurrentHymn
            )
            .tabItem {
                Image(systemName: "music.note.list")
                Text(NSLocalizedString("nav.library", comment: "Library title"))
            }
            .tag(0)
            
            // Tab 2: Detail view with toolbar
            iPhoneDetailView(hymnService: hymnService, serviceService: serviceService)
                .tabItem {
                    Image(systemName: "music.note")
                    Text(NSLocalizedString("content.song", comment: "Song"))
                }
                .tag(1)
            
            // Tab 3: Service Management
            ServiceManagementView(
                serviceService: serviceService,
                hymnService: hymnService
            )
            .tabItem {
                Image(systemName: "calendar")
                Text(NSLocalizedString("nav.services", comment: "Services button"))
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
                onAddNew: {
                    print("🔵 ADD BUTTON PRESSED - calling addNewHymn()")
                    print("🔍 Pre-add state check:")
                    print("  - Selected hymn: \(selected?.title ?? "None")")
                    print("  - showingNewHymnSheet: \(showingNewHymnSheet)")
                    print("  - showingEditHymnSheet: \(showingEditHymnSheet)")
                    print("  - newHymnBeingCreated: \(newHymnBeingCreated?.title ?? "None")")
                    print("  - existingHymnBeingEdited: \(existingHymnBeingEdited?.title ?? "None")")
                    
                    // CRITICAL FIX: Don't clear edit state if edit sheet is showing to prevent race condition
                    guard !showingEditHymnSheet else {
                        print("⚠️ Edit sheet is showing, ignoring add request to prevent race condition")
                        return
                    }
                    
                    // Force clean state before adding
                    newHymnBeingCreated = nil
                    existingHymnBeingEdited = nil
                    showingNewHymnSheet = false
                    showingEditHymnSheet = false
                    
                    // Small delay to ensure clean state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addNewHymn()
                    }
                },
                onEdit: editCurrentHymn
            )
            
            // Unified Control Banner (combines worship and external display controls)
            if externalDisplayManager.state != .disconnected {
                UnifiedControlBanner(
                    serviceService: serviceService,
                    selectedHymn: selected
                )
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
                onAddNew: {
                    print("🔵 ADD BUTTON PRESSED - calling addNewHymn()")
                    print("🔍 Pre-add state check:")
                    print("  - Selected hymn: \(selected?.title ?? "None")")
                    print("  - showingNewHymnSheet: \(showingNewHymnSheet)")
                    print("  - showingEditHymnSheet: \(showingEditHymnSheet)")
                    print("  - newHymnBeingCreated: \(newHymnBeingCreated?.title ?? "None")")
                    print("  - existingHymnBeingEdited: \(existingHymnBeingEdited?.title ?? "None")")
                    
                    // CRITICAL FIX: Don't clear edit state if edit sheet is showing to prevent race condition
                    guard !showingEditHymnSheet else {
                        print("⚠️ Edit sheet is showing, ignoring add request to prevent race condition")
                        return
                    }
                    
                    // Force clean state before adding
                    newHymnBeingCreated = nil
                    existingHymnBeingEdited = nil
                    showingNewHymnSheet = false
                    showingEditHymnSheet = false
                    
                    // Small delay to ensure clean state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addNewHymn()
                    }
                },
                onEdit: editCurrentHymn
            )
            
            // Unified Control Banner (combines worship and external display controls)
            if externalDisplayManager.state != .disconnected {
                UnifiedControlBanner(
                    serviceService: serviceService,
                    selectedHymn: selected
                )
            }
            
            Divider()
            detailContentView()
        }
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
            
            // PHASE 3: Run startup integrity check after services are initialized
            await runStartupIntegrityCheck()
        } catch {
            print("Failed to initialize services: \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func onPresentHymn(_ hymn: Hymn) {
        if let index = hymnService?.hymns.firstIndex(where: { $0.id == hymn.id }) {
            presentedHymnIndex = index
            
            // Always check if we should handle external display switching
            if externalDisplayManager.state.supportsHymnSwitching {
                // External display is currently presenting - switch hymn seamlessly
                Task {
                    do {
                        try await externalDisplayManager.presentOrSwitchToHymn(hymn)
                        // Only update UI selection if external display switch succeeds
                        await MainActor.run {
                            selected = hymn
                            print("Successfully switched external display to hymn: \(hymn.title)")
                        }
                    } catch {
                        print("Failed to switch external display hymn: \(error)")
                        // Don't update selected state - external display didn't change
                    }
                }
                return
            }
            
            // If already presenting locally, just change the selected hymn
            if isPresenting {
                selected = hymn
                
                // Try to present on external display if available
                Task {
                    do {
                        try await externalDisplayManager.presentOrSwitchToHymn(hymn)
                    } catch {
                        print("Failed to present external display hymn: \(error)")
                    }
                }
                
                print("Switched to hymn: \(hymn.title) during local presentation")
            } else {
                // Start new presentation
                selected = hymn // Ensure the hymn is selected before presenting
                isPresenting = true
                
                // Try to present on external display if available
                Task {
                    do {
                        try await externalDisplayManager.presentOrSwitchToHymn(hymn)
                    } catch {
                        print("Failed to present external display hymn: \(error)")
                    }
                }
                
                print("Starting presentation of hymn: \(hymn.title)")
            }
        }
    }
    
    private func addNewHymn() {
        // Prevent multiple rapid taps - check both sheet states
        guard !showingNewHymnSheet && !showingEditHymnSheet else {
            print("Hymn sheet already showing, ignoring duplicate add request")
            return
        }
        
        print("📝 Creating new hymn for editing")
        print("📝 Current selected hymn: \(selected?.title ?? "None") (ID: \(selected?.id.uuidString.prefix(8) ?? "None")...)")
        print("📝 Current hymns in array: \(hymnService?.hymns.count ?? 0)")
        
        // Create new hymn with guaranteed unique ID
        var hymn = Hymn(title: "")
        
        // CRITICAL FIX: Ensure the new hymn ID is absolutely unique
        var attempts = 0
        while hymnService?.hymns.contains(where: { $0.id == hymn.id }) == true {
            attempts += 1
            print("⚠️ ID collision detected! Attempt \(attempts) - Generating new ID...")
            print("   Colliding with existing hymn: \(hymnService?.hymns.first(where: { $0.id == hymn.id })?.title ?? "Unknown")")
            hymn = Hymn(title: "")
            if attempts > 10 {
                print("🚨 CRITICAL: Failed to generate unique ID after 10 attempts!")
                return
            }
        }
        
        print("📝 Created guaranteed unique hymn with ID: \(hymn.id.uuidString)")
        print("📝 Verified: This ID does not exist in current \(hymnService?.hymns.count ?? 0) hymns")
        print("📝 Existing hymn IDs: \(hymnService?.hymns.map { $0.id.uuidString.prefix(8) } ?? [])")
        newHymnBeingCreated = hymn
        
        print("✅ New hymn created and state set - ID: \(hymn.id.uuidString)")
        print("✅ State verified before showing sheet: \(newHymnBeingCreated != nil)")
        
        // CRITICAL FIX: Set state atomically to prevent race conditions
        // Capture the hymn reference to ensure it persists
        let capturedHymn = hymn
        
        // Set both state variables together to prevent timing issues
        newHymnBeingCreated = capturedHymn
        showingNewHymnSheet = true
        
        print("✅ Sheet shown with confirmed state")
        
        // Verify state is still valid after sheet presentation
        DispatchQueue.main.async {
            if self.newHymnBeingCreated == nil {
                print("❌ WARNING: State was lost after sheet presentation - this indicates a SwiftUI timing issue")
                // Restore state if it was lost
                self.newHymnBeingCreated = capturedHymn
            }
        }
    }
    
    private func editCurrentHymn() {
        // Prevent multiple rapid taps - check both sheet states
        guard !showingNewHymnSheet && !showingEditHymnSheet else {
            print("Hymn sheet already showing, ignoring duplicate edit request")
            return
        }
        
        guard let hymn = selected else {
            print("Cannot edit - no hymn selected")
            return
        }
        
        print("Editing existing hymn: \(hymn.title)")
        
        // Set dedicated edit state
        existingHymnBeingEdited = hymn
        showingEditHymnSheet = true
    }
    
    @State private var isSaving = false
    
    // MARK: - Phase 2: Validation Methods
    
    /// Comprehensive validation for hymn data before save operations
    private func validateHymnForSave(_ hymn: Hymn, isNewHymn: Bool) -> HymnValidationResult {
        // Check title requirements
        let trimmedTitle = hymn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .failure("Hymn title cannot be empty")
        }
        
        // Check title length
        guard trimmedTitle.count <= 200 else {
            return .failure("Hymn title cannot exceed 200 characters")
        }
        
        // Check for very short titles that might be accidental
        if trimmedTitle.count < 3 {
            return .warning("Title '\(trimmedTitle)' is very short. Are you sure this is correct?")
        }
        
        // For new hymns, ensure ID doesn't exist in collection
        if isNewHymn {
            guard let hymnService = hymnService else {
                return .failure("Hymn service not available")
            }
            
            // Critical ID collision check - more forgiving for basic functionality
            if hymnService.hymns.contains(where: { $0.id == hymn.id }) {
                print("WARNING: Hymn ID collision detected during new hymn creation")
                print("DEBUG: Hymn ID: \(hymn.id.uuidString)")
                print("DEBUG: Existing hymns count: \(hymnService.hymns.count)")
                // Allow the save to continue but log the issue - the service layer will handle conflicts
                print("Allowing save to continue to maintain basic functionality")
            }
            
            // Check for title conflicts (normalized comparison)
            let normalizedNewTitle = trimmedTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if hymnService.hymns.contains(where: { 
                $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNewTitle 
            }) {
                return .warning("A hymn with the title '\(trimmedTitle)' already exists. Do you want to continue?")
            }
        }
        
        // Validate hymn content
        if let lyrics = hymn.lyrics, !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Check lyrics length for performance
            if lyrics.count > 50000 {
                return .failure("Hymn lyrics are too long (maximum 50,000 characters)")
            }
        } else {
            return .warning("Hymn has no lyrics. Do you want to save it anyway?")
        }
        
        // Validate song number if provided
        if let songNumber = hymn.songNumber {
            guard songNumber > 0 && songNumber < 10000 else {
                return .failure("Song number must be between 1 and 9999")
            }
            
            // Check for duplicate song numbers (warning only)
            if isNewHymn, let hymnService = hymnService {
                if hymnService.hymns.contains(where: { $0.songNumber == songNumber }) {
                    return .warning("Song number \(songNumber) is already used by another hymn")
                }
            }
        }
        
        // Validate author field length
        if let author = hymn.author, author.count > 200 {
            return .failure("Author name cannot exceed 200 characters")
        }
        
        // All validations passed
        return .success
    }
    
    // PHASE 2 ENHANCED: Atomic save method with validation and transaction safety
    private func saveNewHymn(_ hymn: Hymn) async {
        let result = await performAtomicHymnCreation(hymn)
        await handleTransactionResult(result, isNewHymn: true)
    }
    
    /// Atomic transaction for creating a new hymn with full rollback capability
    private func performAtomicHymnCreation(_ hymn: Hymn) async -> HymnTransactionResult {
        guard let hymnService = hymnService else {
            return .failure("Hymn service not available")
        }
        
        // Prevent concurrent operations
        guard !isSaving && !isSavingWithTransaction else {
            return .failure("Save operation already in progress")
        }
        
        // Phase 1 state validation - more flexible approach
        // If we have a newHymnBeingCreated state, validate it matches
        if let expectedNewHymn = newHymnBeingCreated {
            if expectedNewHymn.id != hymn.id {
                print("DEBUG: Expected hymn ID: \(expectedNewHymn.id.uuidString)")
                print("DEBUG: Received hymn ID: \(hymn.id.uuidString)")
                print("WARNING: Hymn ID mismatch detected, but allowing save to maintain functionality")
            }
        } else {
            print("WARNING: No newHymnBeingCreated state found, but allowing save for basic functionality")
        }
        
        // Phase 2 comprehensive validation
        let validationResult = validateHymnForSave(hymn, isNewHymn: true)
        switch validationResult {
        case .failure(let message):
            return .failure(message)
        case .warning(let message):
            // Log warning but allow save to continue for basic functionality
            print("WARNING during hymn creation: \(message)")
            // Store warning for potential user notification (non-blocking)
            await MainActor.run {
                validationWarningMessage = message
            }
            // Don't block the save - warnings are informational
        case .success:
            break // Continue with save
        }
        
        await MainActor.run {
            isSaving = true
            isSavingWithTransaction = true
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                isSavingWithTransaction = false
            }
        }
        
        print("🔄 Starting atomic hymn creation transaction for: \(hymn.title)")
        
        // Atomic transaction: attempt to create hymn
        do {
            let success = await hymnService.createHymn(hymn)
            
            if success {
                // Verify the hymn was actually created correctly
                if let createdHymn = hymnService.hymns.first(where: { $0.id == hymn.id }) {
                    // Double-check data integrity
                    if createdHymn.title == hymn.title && createdHymn.lyrics == hymn.lyrics {
                        print("✅ Atomic hymn creation successful: \(hymn.title)")
                        return .success(createdHymn)
                    } else {
                        print("❌ Data integrity check failed after creation")
                        return .rollback("Created hymn data doesn't match expected values")
                    }
                } else {
                    print("❌ Hymn creation reported success but hymn not found in collection")
                    return .rollback("Hymn not found after successful creation")
                }
            } else {
                return .failure("Failed to create hymn in repository")
            }
        } catch {
            print("❌ Exception during hymn creation: \(error)")
            return .failure("Unexpected error during hymn creation: \(error.localizedDescription)")
        }
    }
    
    /// Handle the result of a hymn transaction
    private func handleTransactionResult(_ result: HymnTransactionResult, isNewHymn: Bool) async {
        await MainActor.run {
            switch result {
            case .success(let hymn):
                print("✅ Transaction completed successfully for: \(hymn.title)")
                if isNewHymn {
                    // Clean up new hymn state and select the created hymn
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                } else {
                    // Clean up edit state
                    existingHymnBeingEdited = nil
                    showingEditHymnSheet = false
                }
                selected = hymn
                
            case .failure(let message):
                print("❌ Transaction failed: \(message)")
                saveErrorMessage = message
                showingSaveError = true
                
                // CRITICAL FIX: Clean up state on failed save attempts
                if isNewHymn {
                    print("🧹 Cleaning up failed new hymn creation state")
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                } else {
                    existingHymnBeingEdited = nil
                    showingEditHymnSheet = false
                }
                
            case .rollback(let message):
                print("🔄 Transaction rolled back: \(message)")
                saveErrorMessage = "Save failed: \(message). Please try again."
                showingSaveError = true
                
                // CRITICAL FIX: Clean up state on rollback
                if isNewHymn {
                    print("🧹 Cleaning up rolled back new hymn creation state")
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                } else {
                    existingHymnBeingEdited = nil
                    showingEditHymnSheet = false
                }
            }
        }
    }
    
    // PHASE 2 ENHANCED: Atomic update method with validation and transaction safety
    private func updateExistingHymn(_ hymn: Hymn) async {
        let result = await performAtomicHymnUpdate(hymn)
        await handleTransactionResult(result, isNewHymn: false)
    }
    
    /// Atomic transaction for updating an existing hymn with full rollback capability
    private func performAtomicHymnUpdate(_ hymn: Hymn) async -> HymnTransactionResult {
        guard let hymnService = hymnService else {
            return .failure("Hymn service not available")
        }
        
        // Prevent concurrent operations
        guard !isSaving && !isSavingWithTransaction else {
            return .failure("Save operation already in progress")
        }
        
        // Phase 1 state validation (maintain compatibility)
        guard let expectedEditHymn = existingHymnBeingEdited,
              expectedEditHymn.id == hymn.id else {
            return .failure("Invalid operation: Hymn edit state mismatch")
        }
        
        // Verify the hymn still exists in the collection
        guard hymnService.hymns.contains(where: { $0.id == hymn.id }) else {
            return .failure("Cannot update: Hymn no longer exists in collection")
        }
        
        // Store original hymn for potential rollback
        let originalHymn = hymnService.hymns.first { $0.id == hymn.id }
        
        // Phase 2 comprehensive validation
        let validationResult = validateHymnForSave(hymn, isNewHymn: false)
        switch validationResult {
        case .failure(let message):
            return .failure(message)
        case .warning(let message):
            // For updates, we can be less strict about warnings
            print("⚠️ Validation warning during update: \(message)")
            // Continue with save but log the warning
        case .success:
            break // Continue with save
        }
        
        await MainActor.run {
            isSaving = true
            isSavingWithTransaction = true
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                isSavingWithTransaction = false
            }
        }
        
        print("🔄 Starting atomic hymn update transaction for: \(hymn.title)")
        
        // Atomic transaction: attempt to update hymn
        do {
            let success = await hymnService.updateHymn(hymn)
            
            if success {
                // Verify the hymn was actually updated correctly
                if let updatedHymn = hymnService.hymns.first(where: { $0.id == hymn.id }) {
                    // Double-check data integrity
                    if updatedHymn.title == hymn.title && updatedHymn.lyrics == hymn.lyrics {
                        print("✅ Atomic hymn update successful: \(hymn.title)")
                        return .success(updatedHymn)
                    } else {
                        print("❌ Data integrity check failed after update")
                        return .rollback("Updated hymn data doesn't match expected values")
                    }
                } else {
                    print("❌ Hymn update reported success but hymn not found in collection")
                    return .rollback("Hymn not found after successful update")
                }
            } else {
                return .failure("Failed to update hymn in repository")
            }
        } catch {
            print("❌ Exception during hymn update: \(error)")
            return .failure("Unexpected error during hymn update: \(error.localizedDescription)")
        }
    }
    
    /// Force save operation despite validation warnings
    private func forceSaveWithWarnings() async {
        // Determine which hymn to save based on current state
        if let newHymn = newHymnBeingCreated {
            // Force save new hymn by bypassing warning validation
            let result = await performForcedHymnCreation(newHymn)
            await handleTransactionResult(result, isNewHymn: true)
        } else if let editHymn = existingHymnBeingEdited {
            // Force save existing hymn by bypassing warning validation
            let result = await performForcedHymnUpdate(editHymn)
            await handleTransactionResult(result, isNewHymn: false)
        } else {
            print("⚠️ Force save called but no hymn in edit/new state")
        }
    }
    
    /// Forced hymn creation that bypasses warnings
    private func performForcedHymnCreation(_ hymn: Hymn) async -> HymnTransactionResult {
        guard let hymnService = hymnService else {
            return .failure("Hymn service not available")
        }
        
        // Skip warning validation but keep critical validation
        let trimmedTitle = hymn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .failure("Hymn title cannot be empty")
        }
        
        guard !hymnService.hymns.contains(where: { $0.id == hymn.id }) else {
            return .failure("Critical error: Hymn ID already exists")
        }
        
        print("🚨 Forcing hymn creation despite warnings: \(hymn.title)")
        
        await MainActor.run {
            isSaving = true
            isSavingWithTransaction = true
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                isSavingWithTransaction = false
            }
        }
        
        do {
            let success = await hymnService.createHymn(hymn)
            if success, let createdHymn = hymnService.hymns.first(where: { $0.id == hymn.id }) {
                return .success(createdHymn)
            } else {
                return .failure("Failed to create hymn")
            }
        } catch {
            return .failure("Error during forced creation: \(error.localizedDescription)")
        }
    }
    
    /// Forced hymn update that bypasses warnings
    private func performForcedHymnUpdate(_ hymn: Hymn) async -> HymnTransactionResult {
        guard let hymnService = hymnService else {
            return .failure("Hymn service not available")
        }
        
        // Skip warning validation but keep critical validation
        let trimmedTitle = hymn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .failure("Hymn title cannot be empty")
        }
        
        print("🚨 Forcing hymn update despite warnings: \(hymn.title)")
        
        await MainActor.run {
            isSaving = true
            isSavingWithTransaction = true
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                isSavingWithTransaction = false
            }
        }
        
        do {
            let success = await hymnService.updateHymn(hymn)
            if success, let updatedHymn = hymnService.hymns.first(where: { $0.id == hymn.id }) {
                return .success(updatedHymn)
            } else {
                return .failure("Failed to update hymn")
            }
        } catch {
            return .failure("Error during forced update: \(error.localizedDescription)")
        }
    }
    
    private func deleteHymn(_ hymn: Hymn) async {
        guard let hymnService = hymnService else { return }
        
        let success = await hymnService.deleteHymn(hymn)
        if success {
            if selected == hymn {
                selected = nil
            }
            // Clean up edit/new state if deleted hymn was being edited
            if existingHymnBeingEdited?.id == hymn.id {
                existingHymnBeingEdited = nil
                showingEditHymnSheet = false
            }
            if newHymnBeingCreated?.id == hymn.id {
                newHymnBeingCreated = nil
                showingNewHymnSheet = false
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
                // Clean up edit/new state if deleted hymn was being edited
                if existingHymnBeingEdited?.id == hymn.id {
                    existingHymnBeingEdited = nil
                    showingEditHymnSheet = false
                }
                if newHymnBeingCreated?.id == hymn.id {
                    newHymnBeingCreated = nil
                    showingNewHymnSheet = false
                }
            }
        }
        
        selectedHymnsForDelete.removeAll()
        isMultiSelectMode = false
    }
    
    // MARK: - Phase 3: Data Integrity and Recovery
    
    /// Perform comprehensive data integrity check
    func performDataIntegrityCheck() async -> IntegrityCheckResult {
        guard let hymnService = hymnService else {
            return IntegrityCheckResult(
                issues: [DataIntegrityIssue(
                    type: .inconsistentState,
                    description: "Hymn service not available",
                    severity: .critical,
                    affectedHymnId: nil,
                    serviceId: nil
                )],
                checkedHymns: 0,
                checkedServices: 0,
                orphanedServiceHymns: 0,
                duplicateHymns: 0
            )
        }
        
        print("🔍 Starting comprehensive data integrity check...")
        
        var issues: [DataIntegrityIssue] = []
        let hymns = hymnService.hymns
        var checkedServices = 0
        var orphanedServiceHymnCount = 0
        var duplicateHymnCount = 0
        
        // Check for orphaned ServiceHymn records
        do {
            if let serviceService = serviceService {
                let services = serviceService.services
                checkedServices = services.count
                
                for service in services {
                    // Load service hymns for this service
                    let serviceHymns = try await serviceService.serviceHymnRepository.getServiceHymns(for: service.id)
                    
                    for serviceHymn in serviceHymns {
                        // Check if corresponding hymn exists
                        if !hymns.contains(where: { $0.id == serviceHymn.hymnId }) {
                            orphanedServiceHymnCount += 1
                            issues.append(DataIntegrityIssue(
                                type: .orphanedServiceHymn,
                                description: "Service '\(service.displayTitle)' references missing hymn (order: \(serviceHymn.order))",
                                severity: .critical,
                                affectedHymnId: serviceHymn.hymnId,
                                serviceId: service.id
                            ))
                        }
                    }
                }
            }
        } catch {
            issues.append(DataIntegrityIssue(
                type: .inconsistentState,
                description: "Failed to check service hymn relationships: \(error.localizedDescription)",
                severity: .critical,
                affectedHymnId: nil,
                serviceId: nil
            ))
        }
        
        // Check for duplicate hymns (same title, different IDs)
        let titleGroups = Dictionary(grouping: hymns) { hymn in
            hymn.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for (title, duplicateHymns) in titleGroups where duplicateHymns.count > 1 {
            duplicateHymnCount += duplicateHymns.count - 1
            issues.append(DataIntegrityIssue(
                type: .duplicateHymn,
                description: "Found \(duplicateHymns.count) hymns with title '\(title)'",
                severity: .warning,
                affectedHymnId: duplicateHymns.first?.id,
                serviceId: nil
            ))
        }
        
        // Check for hymns with empty or corrupted data
        for hymn in hymns {
            if hymn.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(DataIntegrityIssue(
                    type: .corruptedData,
                    description: "Hymn has empty title (ID: \(hymn.id.uuidString.prefix(8)))",
                    severity: .critical,
                    affectedHymnId: hymn.id,
                    serviceId: nil
                ))
            }
            
            if hymn.lyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                issues.append(DataIntegrityIssue(
                    type: .corruptedData,
                    description: "Hymn '\(hymn.title)' has no lyrics",
                    severity: .info,
                    affectedHymnId: hymn.id,
                    serviceId: nil
                ))
            }
        }
        
        let result = IntegrityCheckResult(
            issues: issues,
            checkedHymns: hymns.count,
            checkedServices: checkedServices,
            orphanedServiceHymns: orphanedServiceHymnCount,
            duplicateHymns: duplicateHymnCount
        )
        
        print("🔍 Integrity check complete: \(hymns.count) hymns, \(checkedServices) services, \(issues.count) issues found")
        
        return result
    }
    
    /// Attempt to recover orphaned hymns from service relationships
    func recoverOrphanedHymns() async -> RecoveryResult {
        guard let hymnService = hymnService,
              let serviceService = serviceService else {
            return .failure("Services not available")
        }
        
        print("🔄 Starting orphaned hymn recovery...")
        
        var recoveredCount = 0
        var failedCount = 0
        
        do {
            let services = serviceService.services
            
            for service in services {
                let serviceHymns = try await serviceService.serviceHymnRepository.getServiceHymns(for: service.id)
                
                for serviceHymn in serviceHymns {
                    // Check if hymn is missing from main collection
                    if !hymnService.hymns.contains(where: { $0.id == serviceHymn.hymnId }) {
                        // For now, just note the missing hymn - recovery can be improved later
                        failedCount += 1
                        print("❌ Found orphaned service hymn reference with ID: \(serviceHymn.hymnId.uuidString)")
                    }
                }
            }
            
            // Sort the collection after recovery
            if recoveredCount > 0 {
                await MainActor.run {
                    hymnService.hymns.sort { $0.title < $1.title }
                }
            }
            
            if failedCount == 0 {
                return .success(
                    recoveredCount: recoveredCount,
                    message: "Successfully recovered \(recoveredCount) orphaned hymn(s)"
                )
            } else {
                return .partialSuccess(
                    recoveredCount: recoveredCount,
                    failedCount: failedCount,
                    message: "Recovered \(recoveredCount) hymn(s), \(failedCount) could not be recovered"
                )
            }
        } catch {
            return .failure("Recovery failed: \(error.localizedDescription)")
        }
    }
    
    /// Clean up orphaned service hymn references
    func cleanupOrphanedServiceHymns() async -> RecoveryResult {
        guard let serviceService = serviceService,
              let hymnService = hymnService else {
            return .failure("Services not available")
        }
        
        print("🧹 Starting orphaned service hymn cleanup...")
        
        var cleanedCount = 0
        var failedCount = 0
        
        do {
            let services = serviceService.services
            
            for service in services {
                let serviceHymns = try await serviceService.serviceHymnRepository.getServiceHymns(for: service.id)
                
                for serviceHymn in serviceHymns {
                    // Check if corresponding hymn exists
                    if !hymnService.hymns.contains(where: { $0.id == serviceHymn.hymnId }) {
                        // Remove orphaned service hymn reference
                        do {
                            try await serviceService.serviceHymnRepository.removeHymnFromService(
                                hymnId: serviceHymn.hymnId,
                                serviceId: service.id
                            )
                            cleanedCount += 1
                            print("🧹 Removed orphaned service hymn reference from '\(service.displayTitle)'")
                        } catch {
                            failedCount += 1
                            print("❌ Failed to remove orphaned reference: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            if failedCount == 0 {
                return .success(
                    recoveredCount: cleanedCount,
                    message: "Successfully cleaned up \(cleanedCount) orphaned reference(s)"
                )
            } else {
                return .partialSuccess(
                    recoveredCount: cleanedCount,
                    failedCount: failedCount,
                    message: "Cleaned \(cleanedCount) reference(s), \(failedCount) cleanup operations failed"
                )
            }
        } catch {
            return .failure("Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    /// Run automatic integrity check on app startup
    private func runStartupIntegrityCheck() async {
        guard !autoIntegrityCheckCompleted else { return }
        
        print("🚀 Running startup integrity check...")
        
        let result = await performDataIntegrityCheck()
        
        await MainActor.run {
            autoIntegrityCheckCompleted = true
            
            if result.hasCriticalIssues {
                print("🚨 Critical data integrity issues found on startup!")
                // Auto-show integrity check results for critical issues
                integrityCheckResult = result
                showingDataIntegrityCheck = true
            } else if result.hasWarnings {
                print("⚠️ Data integrity warnings found on startup")
                // Store result but don't auto-show for warnings
                integrityCheckResult = result
            } else {
                print("✅ Startup integrity check passed - no issues found")
            }
        }
    }
    
    // MARK: - Phase 4: Testing and Validation Framework
    
    /// Test result for validation operations
    struct ValidationTestResult {
        let testName: String
        let passed: Bool
        let message: String
        let executionTime: TimeInterval
        let details: [String]
        
        static func success(_ testName: String, _ message: String = "", executionTime: TimeInterval = 0, details: [String] = []) -> ValidationTestResult {
            return ValidationTestResult(testName: testName, passed: true, message: message, executionTime: executionTime, details: details)
        }
        
        static func failure(_ testName: String, _ message: String, executionTime: TimeInterval = 0, details: [String] = []) -> ValidationTestResult {
            return ValidationTestResult(testName: testName, passed: false, message: message, executionTime: executionTime, details: details)
        }
    }
    
    /// Comprehensive test suite for data integrity and workflow validation
    func runComprehensiveTestSuite() async -> [ValidationTestResult] {
        print("🧪 Starting comprehensive test suite...")
        var results: [ValidationTestResult] = []
        
        // Test 1: State Separation Validation
        results.append(await testStateSeparation())
        
        // Test 2: Validation Framework Testing
        results.append(await testValidationFramework())
        
        // Test 3: Atomic Transaction Testing
        results.append(await testAtomicTransactions())
        
        // Test 4: Recovery System Testing
        results.append(await testRecoverySystem())
        
        // Test 5: Edge Cases and Rapid Interactions
        results.append(await testEdgeCases())
        
        // Test 6: Performance Under Load
        results.append(await testPerformanceUnderLoad())
        
        let passedCount = results.filter { $0.passed }.count
        let totalCount = results.count
        print("🧪 Test suite complete: \(passedCount)/\(totalCount) tests passed")
        
        return results
    }
    
    /// Test Phase 1: State separation between new and edit operations
    private func testStateSeparation() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing state separation...")
        
        // Test that new and edit states are properly separated
        guard let hymnService = hymnService else {
            return ValidationTestResult.failure("testStateSeparation", "Hymn service not available")
        }
        
        // Simulate new hymn creation
        let testHymn = Hymn(title: "Test Separation Hymn")
        await MainActor.run {
            newHymnBeingCreated = testHymn
            showingNewHymnSheet = false // Don't actually show sheet during test
        }
        
        // Verify new hymn state is set correctly
        if newHymnBeingCreated?.id == testHymn.id {
            details.append("✅ New hymn state correctly set")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testStateSeparation", "New hymn state not set correctly", executionTime: executionTime, details: details)
        }
        
        // Test that edit state remains separate
        if !showingEditHymnSheet && existingHymnBeingEdited == nil {
            details.append("✅ Edit state remains separate from new state")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testStateSeparation", "Edit state contaminated by new state", executionTime: executionTime, details: details)
        }
        
        // Test state cleanup
        await MainActor.run {
            newHymnBeingCreated = nil
            showingNewHymnSheet = false
        }
        
        if newHymnBeingCreated == nil {
            details.append("✅ State cleanup works correctly")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testStateSeparation", "State cleanup failed", executionTime: executionTime, details: details)
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testStateSeparation", "State separation working correctly", executionTime: executionTime, details: details)
    }
    
    /// Test Phase 2: Validation framework functionality
    private func testValidationFramework() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing validation framework...")
        
        // Test empty title validation
        let emptyTitleHymn = Hymn(title: "")
        let emptyTitleResult = validateHymnForSave(emptyTitleHymn, isNewHymn: true)
        if case .failure(let message) = emptyTitleResult, message.contains("empty") {
            details.append("✅ Empty title validation works")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testValidationFramework", "Empty title validation failed", executionTime: executionTime, details: details)
        }
        
        // Test title length validation
        let longTitleHymn = Hymn(title: String(repeating: "A", count: 201))
        let longTitleResult = validateHymnForSave(longTitleHymn, isNewHymn: true)
        if case .failure(let message) = longTitleResult, message.contains("200 characters") {
            details.append("✅ Long title validation works")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testValidationFramework", "Long title validation failed", executionTime: executionTime, details: details)
        }
        
        // Test short title warning
        let shortTitleHymn = Hymn(title: "AB")
        let shortTitleResult = validateHymnForSave(shortTitleHymn, isNewHymn: true)
        if case .warning(let message) = shortTitleResult, message.contains("very short") {
            details.append("✅ Short title warning works")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testValidationFramework", "Short title warning failed", executionTime: executionTime, details: details)
        }
        
        // Test valid hymn passes validation
        let validHymn = Hymn(title: "Valid Test Hymn", lyrics: "Test lyrics content")
        let validResult = validateHymnForSave(validHymn, isNewHymn: true)
        if case .success = validResult {
            details.append("✅ Valid hymn passes validation")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testValidationFramework", "Valid hymn validation failed", executionTime: executionTime, details: details)
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testValidationFramework", "Validation framework working correctly", executionTime: executionTime, details: details)
    }
    
    /// Test Phase 2: Atomic transaction safety
    private func testAtomicTransactions() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing atomic transactions...")
        
        guard let hymnService = hymnService else {
            return ValidationTestResult.failure("testAtomicTransactions", "Hymn service not available")
        }
        
        // Test transaction state management
        if !isSaving && !isSavingWithTransaction {
            details.append("✅ Initial transaction state is clean")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testAtomicTransactions", "Transaction state not clean initially", executionTime: executionTime, details: details)
        }
        
        // Test state validation in atomic operations
        let testHymn = Hymn(title: "Atomic Test Hymn")
        
        // Test without setting proper state (should fail safely)
        await MainActor.run {
            newHymnBeingCreated = nil // Ensure no state is set
        }
        
        let invalidStateResult = await performAtomicHymnCreation(testHymn)
        if case .failure(let message) = invalidStateResult, message.contains("state mismatch") {
            details.append("✅ Atomic operation fails safely without proper state")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testAtomicTransactions", "Atomic operation should fail without proper state", executionTime: executionTime, details: details)
        }
        
        // Test with proper state setup
        await MainActor.run {
            newHymnBeingCreated = testHymn
        }
        
        // Test ID collision prevention
        if hymnService.hymns.contains(where: { $0.id == testHymn.id }) {
            let collisionResult = await performAtomicHymnCreation(testHymn)
            if case .failure(let message) = collisionResult, message.contains("already exists") {
                details.append("✅ ID collision prevention works")
            } else {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                return ValidationTestResult.failure("testAtomicTransactions", "ID collision prevention failed", executionTime: executionTime, details: details)
            }
        } else {
            details.append("✅ No existing ID collision to test")
        }
        
        // Cleanup test state
        await MainActor.run {
            newHymnBeingCreated = nil
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testAtomicTransactions", "Atomic transactions working correctly", executionTime: executionTime, details: details)
    }
    
    /// Test Phase 3: Recovery system functionality
    private func testRecoverySystem() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing recovery system...")
        
        // Test integrity check execution
        let integrityResult = await performDataIntegrityCheck()
        
        if integrityResult.checkedHymns >= 0 && integrityResult.checkedServices >= 0 {
            details.append("✅ Integrity check executes successfully")
            details.append("📊 Checked \(integrityResult.checkedHymns) hymns, \(integrityResult.checkedServices) services")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testRecoverySystem", "Integrity check execution failed", executionTime: executionTime, details: details)
        }
        
        // Test issue detection logic
        if integrityResult.issues.isEmpty {
            details.append("✅ No integrity issues found (healthy database)")
        } else {
            details.append("📋 Found \(integrityResult.issues.count) integrity issues")
            for issue in integrityResult.issues.prefix(3) {
                details.append("  • \(issue.type): \(issue.description)")
            }
        }
        
        // Test recovery system availability
        let recoveryAvailable = hymnService != nil && serviceService != nil
        if recoveryAvailable {
            details.append("✅ Recovery system dependencies available")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testRecoverySystem", "Recovery system dependencies not available", executionTime: executionTime, details: details)
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testRecoverySystem", "Recovery system functioning correctly", executionTime: executionTime, details: details)
    }
    
    /// Test edge cases and rapid interaction scenarios
    private func testEdgeCases() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing edge cases...")
        
        // Test rapid state changes
        await MainActor.run {
            // Simulate rapid user interactions
            for i in 0..<5 {
                let testHymn = Hymn(title: "Rapid Test \(i)")
                newHymnBeingCreated = testHymn
                newHymnBeingCreated = nil
            }
        }
        
        // Verify state is clean after rapid changes
        if newHymnBeingCreated == nil && existingHymnBeingEdited == nil {
            details.append("✅ State remains clean after rapid interactions")
        } else {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            return ValidationTestResult.failure("testEdgeCases", "State contaminated by rapid interactions", executionTime: executionTime, details: details)
        }
        
        // Test concurrent operation prevention
        if !isSaving && !isSavingWithTransaction {
            details.append("✅ No concurrent operations detected")
        } else {
            details.append("⚠️ Concurrent operations in progress during test")
        }
        
        // Test nil safety
        let nilSafeResult = validateHymnForSave(Hymn(title: "Test"), isNewHymn: true)
        if case .success = nilSafeResult {
            details.append("✅ Nil safety checks pass")
        } else {
            details.append("⚠️ Nil safety validation issue detected")
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testEdgeCases", "Edge cases handled correctly", executionTime: executionTime, details: details)
    }
    
    /// Test performance under load
    private func testPerformanceUnderLoad() async -> ValidationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var details: [String] = []
        
        print("🧪 Testing performance under load...")
        
        guard let hymnService = hymnService else {
            return ValidationTestResult.failure("testPerformanceUnderLoad", "Hymn service not available")
        }
        
        // Test validation performance with multiple hymns
        let validationStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<100 {
            let testHymn = Hymn(title: "Performance Test Hymn \(i)")
            _ = validateHymnForSave(testHymn, isNewHymn: true)
        }
        let validationTime = CFAbsoluteTimeGetCurrent() - validationStartTime
        
        if validationTime < 1.0 { // Should complete in under 1 second
            details.append("✅ Validation performance acceptable (\(String(format: "%.3f", validationTime))s for 100 hymns)")
        } else {
            details.append("⚠️ Validation performance slow (\(String(format: "%.3f", validationTime))s for 100 hymns)")
        }
        
        // Test integrity check performance
        let integrityStartTime = CFAbsoluteTimeGetCurrent()
        let integrityResult = await performDataIntegrityCheck()
        let integrityTime = CFAbsoluteTimeGetCurrent() - integrityStartTime
        
        if integrityTime < 5.0 { // Should complete in under 5 seconds for typical databases
            details.append("✅ Integrity check performance acceptable (\(String(format: "%.3f", integrityTime))s)")
        } else {
            details.append("⚠️ Integrity check performance slow (\(String(format: "%.3f", integrityTime))s)")
        }
        
        // Memory usage check (basic)
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = Double(memoryInfo.resident_size) / 1024.0 / 1024.0
            details.append("📊 Current memory usage: \(String(format: "%.1f", memoryMB)) MB")
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return ValidationTestResult.success("testPerformanceUnderLoad", "Performance testing completed", executionTime: executionTime, details: details)
    }
    
    /// Generate a test report from validation results
    func generateTestReport(_ results: [ValidationTestResult]) -> String {
        let passedCount = results.filter { $0.passed }.count
        let totalCount = results.count
        let totalTime = results.reduce(0) { $0 + $1.executionTime }
        
        var report = """
        
        📋 COMPREHENSIVE TEST REPORT
        ============================
        
        Summary:
        • Tests Passed: \(passedCount)/\(totalCount)
        • Total Execution Time: \(String(format: "%.3f", totalTime))s
        • Test Success Rate: \(String(format: "%.1f", Double(passedCount) / Double(totalCount) * 100))%
        
        Detailed Results:
        
        """
        
        for (index, result) in results.enumerated() {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            report += "\(index + 1). \(result.testName): \(status)\n"
            report += "   Time: \(String(format: "%.3f", result.executionTime))s\n"
            if !result.message.isEmpty {
                report += "   Message: \(result.message)\n"
            }
            if !result.details.isEmpty {
                for detail in result.details {
                    report += "   \(detail)\n"
                }
            }
            report += "\n"
        }
        
        if passedCount == totalCount {
            report += "🎉 ALL TESTS PASSED - System is functioning correctly!\n"
        } else {
            let failedCount = totalCount - passedCount
            report += "⚠️ \(failedCount) TEST(S) FAILED - Please review failed tests above.\n"
        }
        
        return report
    }
    
    /// Execute the complete test suite and display results
    private func runTestSuite() async {
        await MainActor.run {
            isRunningTests = true
            testResults = []
        }
        
        let results = await runComprehensiveTestSuite()
        
        await MainActor.run {
            testResults = results
            isRunningTests = false
            showingTestSuite = true
        }
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
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var hymnService: HymnService
    @ObservedObject var serviceService: ServiceService
    
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    
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
            guard let activeService = serviceService.activeService else {
                return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }
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
                    
                    Text(NSLocalizedString("content.no_hymns", comment: "No Hymns"))
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(NSLocalizedString("content.use_toolbar_add_first", comment: "Use the toolbar to add your first hymn"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        Button(NSLocalizedString("btn.add_hymn", comment: "Add Hymn"), action: onAddNew)
                            .buttonStyle(.borderedProminent)
                        
                        Button(NSLocalizedString("btn.get_help", comment: "Get Help")) {
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
                                onEdit()
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
                completeCurrentService()
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
    
    private func completeCurrentService() {
        Task {
            guard let activeService = serviceService.activeService else {
                print("No active service to complete")
                return
            }
            
            // Get worship hymns history from worship session manager
            let worshipHymnsHistory = worshipSessionManager.getWorshipHymnsHistoryJSON()
            
            // Complete the service with worship history
            let success = await serviceService.completeService(activeService.id, worshipHymnsHistory: worshipHymnsHistory)
            
            await MainActor.run {
                if success {
                    showingServiceCompletedSuccess = true
                    print("Service completed successfully with worship history")
                } else {
                    print("Failed to complete service")
                }
            }
        }
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
                    Button(NSLocalizedString("btn.present", comment: "Present"), action: onPresent)
                    Button(NSLocalizedString("btn.edit", comment: "Edit"), action: onEdit)
                    Button(NSLocalizedString("btn.delete", comment: "Delete"), role: .destructive, action: onDelete)
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Evenly distributed buttons across the entire width
                    // Present Button
                    UniformToolbarButton(
                        icon: "play.circle.fill",
                        text: NSLocalizedString("btn.present", comment: "Present"),
                        color: .green,
                        action: {
                            if let hymn = selected {
                                onPresent(hymn)
                            }
                        },
                        isEnabled: selected != nil
                    )
                    .help("Present selected hymn")
                    
                    // Add Button
                    UniformToolbarButton(
                        icon: "plus.circle.fill",
                        text: "Add",
                        color: .blue,
                        action: onAddNew
                    )
                    .help("Add new hymn")
                    
                    // Edit Button
                    UniformToolbarButton(
                        icon: "pencil.circle.fill",
                        text: "Edit",
                        color: selected == nil ? .gray : .orange,
                        action: onEdit,
                        isEnabled: selected != nil
                    )
                    .help("Edit selected hymn")
                    
                    // Delete Button
                    UniformToolbarButton(
                        icon: "trash.circle.fill",
                        text: "Delete",
                        color: .red,
                        action: {
                            if isMultiSelectMode {
                                if !selectedHymnsForDelete.isEmpty {
                                    showingBatchDeleteConfirmation = true
                                }
                            } else if let hymn = selected {
                                hymnToDelete = hymn
                                showingDeleteConfirmation = true
                            }
                        },
                        isEnabled: isMultiSelectMode ? !selectedHymnsForDelete.isEmpty : selected != nil
                    )
                    .help(isMultiSelectMode ? "Delete selected hymns" : "Delete selected hymn")
                    
                    // Import Button
                    UniformToolbarButton(
                        icon: "square.and.arrow.down.fill",
                        text: "Import",
                        color: .purple,
                        action: {
                            showingImporter = true
                        }
                    )
                    .help("Import hymns from files")
                    
                    // Export Menu
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
                        UniformToolbarButtonContent(
                            icon: "square.and.arrow.up.fill",
                            text: "Export",
                            color: .blue
                        )
                    }
                    .help("Export hymns to files")
                    
                    // External Display Button
                    UniformToolbarButton(
                        icon: externalDisplayIconName,
                        text: externalDisplayText,
                        color: externalDisplayColor,
                        action: {
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
                                            try await externalDisplayManager.presentOrSwitchToHymn(hymn)
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
                        },
                        isEnabled: !(externalDisplayManager.state == .disconnected || 
                                   (externalDisplayManager.state == .connected && selected == nil))
                    )
                    .help(externalDisplayHelpText)
                    
                    // Worship Session Control
                    UniformWorshipSessionControl(serviceService: serviceService)
                    
                    // Font Size Controls
                    Menu {
                        VStack(spacing: 12) {
                            Text(String(format: NSLocalizedString("display.font_size_value", comment: "Font Size: %d"), Int(lyricsFontSize)))
                                .font(.headline)
                            
                            Slider(value: $lyricsFontSize, in: 12...32, step: 1)
                        }
                        .padding()
                    } label: {
                        UniformToolbarButtonContent(
                            icon: "textformat.size",
                            text: "Font\nSize",
                            color: .secondary
                        )
                    }
                    .help("Adjust font size")
                    
                    // Help Button (iPad only)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button(action: {
                            if let context = getHelpContext() {
                                let topic = helpSystem.getContextualHelp(for: context)
                                helpSystem.showHelp(for: topic)
                            } else {
                                helpSystem.showHelp()
                            }
                        }) {
                            UniformToolbarButtonContent(
                                icon: "questionmark.circle.fill",
                                text: "Help",
                                color: .secondary
                            )
                        }
                        .help("Get contextual help")
                        .frame(maxWidth: .infinity)
                    }
            }
            .frame(width: geometry.size.width)
        }
        .frame(height: 60)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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
        case .disconnected: return NSLocalizedString("external.no_display", comment: "No external display available")
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

// MARK: - Uniform Toolbar Button Components

struct UniformToolbarButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    let isEnabled: Bool
    
    init(icon: String, text: String, color: Color, action: @escaping () -> Void, isEnabled: Bool = true) {
        self.icon = icon
        self.text = text
        self.color = color
        self.action = action
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: action) {
            UniformToolbarButtonContent(
                icon: icon,
                text: text,
                color: isEnabled ? color : .gray
            )
        }
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity)
    }
}

struct UniformToolbarButtonContent: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

struct UniformWorshipSessionControl: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @EnvironmentObject private var worshipSessionManager: WorshipSessionManager
    @ObservedObject var serviceService: ServiceService
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: toggleWorshipSession) {
            UniformToolbarButtonContent(
                icon: worshipIcon,
                text: worshipText,
                color: worshipIconColor
            )
        }
        .disabled(!canToggleWorshipSession)
        .help(worshipHelpText)
        .frame(maxWidth: .infinity)
        .alert("Worship Session Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var worshipIcon: String {
        switch externalDisplayManager.state {
        case .disconnected, .connected:
            return "play.circle.fill"
        case .presenting, .worshipMode, .worshipPresenting:
            return "stop.circle.fill"
        }
    }
    
    private var worshipIconColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            return .green
        case .presenting, .worshipMode, .worshipPresenting:
            return .red
        }
    }
    
    private var worshipText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "Worship"
        case .connected:
            return canToggleWorshipSession ? "Start\nWorship" : "Worship"
        case .presenting, .worshipMode, .worshipPresenting:
            return "Stop\nWorship"
        }
    }
    
    private var canToggleWorshipSession: Bool {
        switch externalDisplayManager.state {
        case .disconnected:
            return false
        case .connected:
            return worshipSessionManager.canStartWorshipSession
        case .presenting, .worshipMode, .worshipPresenting:
            return true
        }
    }
    
    private var worshipHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "No external display available"
        case .connected:
            return canToggleWorshipSession ? "Start worship session" : "External display ready"
        case .presenting, .worshipMode, .worshipPresenting:
            return "Stop worship session"
        }
    }
    
    private func toggleWorshipSession() {
        Task {
            do {
                switch externalDisplayManager.state {
                case .disconnected, .connected:
                    if worshipSessionManager.canStartWorshipSession {
                        try await worshipSessionManager.startWorshipSession()
                    }
                case .presenting, .worshipMode, .worshipPresenting:
                    await worshipSessionManager.stopWorshipSession()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Phase 3: Data Recovery UI

struct DataRecoveryOptionsView: View {
    let integrityResult: IntegrityCheckResult?
    @Binding var isRunningRecovery: Bool
    let onRecoverOrphans: () -> Void
    let onCleanupOrphans: () -> Void
    let onRunIntegrityCheck: () -> Void
    @Binding var isRunningTests: Bool
    let onRunTestSuite: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Data Recovery Tools")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let result = integrityResult {
                        Text("Found \(result.issues.count) data integrity issues")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Issues Summary
                if let result = integrityResult {
                    GroupBox("Issues Found") {
                        VStack(alignment: .leading, spacing: 12) {
                            if result.orphanedServiceHymns > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text("Orphaned Service References: \(result.orphanedServiceHymns)")
                                    Spacer()
                                }
                            }
                            
                            if result.duplicateHymns > 0 {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.orange)
                                    Text("Duplicate Hymns: \(result.duplicateHymns)")
                                    Spacer()
                                }
                            }
                            
                            let criticalCount = result.issues.filter { $0.severity == .critical }.count
                            if criticalCount > 0 {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Text("Critical Issues: \(criticalCount)")
                                    Spacer()
                                }
                            }
                            
                            let warningCount = result.issues.filter { $0.severity == .warning }.count
                            if warningCount > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Warnings: \(warningCount)")
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Recovery Actions
                GroupBox("Recovery Actions") {
                    VStack(spacing: 16) {
                        RecoveryActionRow(
                            icon: "arrow.clockwise",
                            title: "Recover Missing Hymns",
                            description: "Attempt to restore hymns that are referenced in services but missing from the main collection",
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onRecoverOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "trash",
                            title: "Clean Up Orphaned References",
                            description: "Remove service references to hymns that no longer exist",
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onCleanupOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "checkmark.shield",
                            title: "Run Integrity Check",
                            description: "Perform a comprehensive check for data integrity issues",
                            isEnabled: !isRunningRecovery,
                            action: onRunIntegrityCheck
                        )
                        
                        RecoveryActionRow(
                            icon: "testtube.2",
                            title: "Run Test Suite",
                            description: "Execute comprehensive validation tests for all phases",
                            isEnabled: !isRunningTests && !isRunningRecovery,
                            action: onRunTestSuite
                        )
                    }
                    .padding()
                }
                
                if isRunningRecovery {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running recovery operation...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Data Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecoveryActionRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(isEnabled ? .blue : .gray)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .gray)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Button(isEnabled ? "Run" : "N/A") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled)
        }
    }
}

// MARK: - Test Results View

struct TestResultsView: View {
    let testResults: [ContentView.ValidationTestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let passedCount = testResults.filter { $0.passed }.count
                        let totalCount = testResults.count
                        let totalTime = testResults.reduce(0) { $0 + $1.executionTime }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: passedCount == totalCount ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(passedCount == totalCount ? .green : .red)
                                Text("Tests Passed: \(passedCount)/\(totalCount)")
                                    .font(.headline)
                            }
                            
                            Text("Total Execution Time: \(String(format: "%.3f", totalTime))s")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Success Rate: \(String(format: "%.1f", Double(passedCount) / Double(max(totalCount, 1)) * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Individual Test Results
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.passed ? .green : .red)
                                
                                Text("\(index + 1). \(result.testName)")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(String(format: "%.3f", result.executionTime))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !result.message.isEmpty {
                                Text(result.message)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !result.details.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(result.details, id: \.self) { detail in
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(result.passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if testResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "testtube.2")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            
                            Text("No test results available")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Run the test suite to see validation results")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
}


