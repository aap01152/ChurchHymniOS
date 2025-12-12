import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import Foundation

struct ContentView: View {
    @EnvironmentObject private var serviceFactory: ServiceFactory
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @Environment(\.openWindow) private var openWindow
    
    // Service layer instances
    @State private var hymnService: HymnService?
    @State private var serviceService: ServiceService?
    @State private var servicesInitialized = false
    
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
    
    // Font size state
    @State private var lyricsFontSize: CGFloat = 16
    
    // Navigation split view visibility state
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        .overlay {
            // External Display Preview Window
            if UIDevice.current.userInterfaceIdiom == .pad {
                ManagedExternalDisplayPreview()
                    .allowsHitTesting(true)
            }
        }
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
        .sheet(isPresented: $showingEdit) {
            if let hymn = editHymn ?? newHymn {
                HymnEditView(hymn: hymn) { savedHymn in
                    Task {
                        await saveHymn(savedHymn)
                    }
                }
            }
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
                        importPreview = nil
                        if success {
                            Task {
                                await hymnService?.loadHymns()
                            }
                        }
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
                onPresent: onPresentHymn,
                onAddNew: addNewHymn,
                onEdit: editCurrentHymn
            )
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Services") {
                        showingServiceManagement = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ExternalDisplayNavigationIndicator()
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
                    lyricsFontSize: $lyricsFontSize
                )
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Service Initialization
    
    private func initializeServices() async {
        guard !servicesInitialized else { return }
        
        do {
            let hymnService = try await serviceFactory.createHymnService()
            let serviceService = try await serviceFactory.createServiceService()
            let operations = try await serviceFactory.createHymnOperations()
            
            await MainActor.run {
                self.hymnService = hymnService
                self.serviceService = serviceService
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
            isPresenting = true
        }
    }
    
    private func addNewHymn() {
        let hymn = Hymn(title: "")
        newHymn = hymn
        selected = hymn
        showingEdit = true
    }
    
    private func editCurrentHymn() {
        if let hymn = selected {
            editHymn = hymn
            showingEdit = true
        }
    }
    
    private func saveHymn(_ hymn: Hymn) async {
        guard let hymnService = hymnService else { return }
        
        let isNewHymn = newHymn == hymn
        
        let success = if isNewHymn {
            await hymnService.createHymn(hymn)
        } else {
            await hymnService.updateHymn(hymn)
        }
        
        if success {
            if isNewHymn {
                newHymn = nil
            }
            editHymn = nil
            showingEdit = false
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
                    }
                }
                
            case .failure(let error):
                print("Import failed: \(error)")
            }
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        Task {
            switch result {
            case .success(let url):
                guard let manager = importExportManager else { return }
                let success = await manager.exportHymns(exportHymns, to: url, format: exportFormat)
                print(success ? "Export completed successfully" : "Export failed")
                
            case .failure(let error):
                print("Export failed: \(error)")
            }
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
    
    let onPresent: (Hymn) -> Void
    let onAddNew: () -> Void
    let onEdit: () -> Void
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .title
    
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
    
    var body: some View {
        VStack {
            // Toolbar
            HStack {
                if !isMultiSelectMode {
                    Button("Add", action: onAddNew)
                        .foregroundColor(.accentColor)
                } else {
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
                }
                
                Spacer()
                
                Button(isMultiSelectMode ? "Done" : "Select") {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        selectedHymnsForDelete.removeAll()
                    }
                }
                
                if isMultiSelectMode && !selectedHymnsForDelete.isEmpty {
                    Button("Delete Selected (\(selectedHymnsForDelete.count))") {
                        showingBatchDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()
            
            // Sort options picker (only show when not in multi-select mode)
            if !isMultiSelectMode {
                Picker(NSLocalizedString("sort.by", comment: "Sort by picker"), selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option as SortOption)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
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
                    
                    Text("Tap 'Add' to create your first hymn")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Hymn", action: onAddNew)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(filteredHymns) { hymn in
                    HymnRowView(
                        hymn: hymn,
                        isSelected: selected?.id == hymn.id,
                        isMarkedForDelete: selectedHymnsForDelete.contains(hymn.id),
                        isMultiSelectMode: isMultiSelectMode,
                        onTap: {
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
                            selected = hymn
                            editHymn = hymn
                            showingEdit = true
                        },
                        onDelete: {
                            hymnToDelete = hymn
                            showingDeleteConfirmation = true
                        },
                        onPresent: { onPresent(hymn) }
                    )
                }
                .searchable(text: $searchText, prompt: "Search hymns...")
            }
        }
        .task {
            if hymnService.hymns.isEmpty && !hymnService.isLoading {
                await hymnService.loadHymns()
            }
        }
    }
}

struct HymnRowView: View {
    let hymn: Hymn
    let isSelected: Bool
    let isMarkedForDelete: Bool
    let isMultiSelectMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPresent: () -> Void
    
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
            
            if !isMultiSelectMode {
                Menu {
                    Button("Present", action: onPresent)
                    Button("Edit", action: onEdit)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : nil)
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
                            .foregroundColor(.orange)
                        Text("Edit")
                            .font(.caption)
                            .foregroundColor(.primary)
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
                
                // Font Size Controls with label
                Menu {
                    VStack(spacing: 12) {
                        Text("Font Size: \(Int(lyricsFontSize))")
                            .font(.headline)
                        HStack {
                            Button("-") { 
                                lyricsFontSize = max(12, lyricsFontSize - 2)
                            }
                            .disabled(lyricsFontSize <= 12)
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("+") { 
                                lyricsFontSize = min(32, lyricsFontSize + 2)
                            }
                            .disabled(lyricsFontSize >= 32)
                            .buttonStyle(.bordered)
                        }
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
        }
    }
    
    private var externalDisplayColor: Color {
        switch externalDisplayManager.state {
        case .disconnected: return .gray
        case .connected: return .green
        case .presenting: return .orange
        }
    }
    
    private var externalDisplayText: String {
        switch externalDisplayManager.state {
        case .disconnected: return "No Display"
        case .connected: return "External"
        case .presenting: return "Stop External"
        }
    }
    
    private var externalDisplayHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected: return "No external display"
        case .connected: return "Present to external display"
        case .presenting: return "Stop external presentation"
        }
    }
}


