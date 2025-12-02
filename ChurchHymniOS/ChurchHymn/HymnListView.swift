import SwiftUI
import SwiftData

struct HymnListView: View {
    let hymns: [Hymn]
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var editHymn: Hymn?
    @Binding var showingEdit: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    
    // Add toolbar-related bindings
    @Binding var newHymn: Hymn?
    @Binding var importType: ImportType?
    @Binding var currentImportType: ImportType?
    @Binding var selectedHymnsForExport: Set<UUID>
    @Binding var showingExportSelection: Bool
    @Binding var showingImportHelp: Bool
    @Binding var showingManageWindow: Bool
    
    let context: ModelContext
    let onPresent: (Hymn) -> Void
    
    // MARK: - Service-related properties
    @StateObject private var serviceOperations: ServiceOperations
    @Query private var services: [WorshipService]
    @Query private var serviceHymns: [ServiceHymn]
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .title
    @State private var isReorderMode = false
    @State private var isServiceManagementMode = false
    @State private var isServiceBarCollapsed = false
    @State private var showingClearAllConfirmation = false
    @State private var showingCompleteServiceConfirmation = false
    @State private var showingNewServicePrompt = false
    @State private var showServiceCompletedSuccess = false
    
    // MARK: - Initializers
    init(
        hymns: [Hymn],
        selected: Binding<Hymn?>,
        selectedHymnsForDelete: Binding<Set<UUID>>,
        isMultiSelectMode: Binding<Bool>,
        editHymn: Binding<Hymn?>,
        showingEdit: Binding<Bool>,
        hymnToDelete: Binding<Hymn?>,
        showingDeleteConfirmation: Binding<Bool>,
        showingBatchDeleteConfirmation: Binding<Bool>,
        newHymn: Binding<Hymn?>,
        importType: Binding<ImportType?>,
        currentImportType: Binding<ImportType?>,
        selectedHymnsForExport: Binding<Set<UUID>>,
        showingExportSelection: Binding<Bool>,
        showingImportHelp: Binding<Bool>,
        showingManageWindow: Binding<Bool>,
        context: ModelContext,
        onPresent: @escaping (Hymn) -> Void
    ) {
        self.hymns = hymns
        self._selected = selected
        self._selectedHymnsForDelete = selectedHymnsForDelete
        self._isMultiSelectMode = isMultiSelectMode
        self._editHymn = editHymn
        self._showingEdit = showingEdit
        self._hymnToDelete = hymnToDelete
        self._showingDeleteConfirmation = showingDeleteConfirmation
        self._showingBatchDeleteConfirmation = showingBatchDeleteConfirmation
        self._newHymn = newHymn
        self._importType = importType
        self._currentImportType = currentImportType
        self._selectedHymnsForExport = selectedHymnsForExport
        self._showingExportSelection = showingExportSelection
        self._showingImportHelp = showingImportHelp
        self._showingManageWindow = showingManageWindow
        self.context = context
        self.onPresent = onPresent
        self._serviceOperations = StateObject(wrappedValue: ServiceOperations(context: context))
    }
    
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
    
    // MARK: - Service Helper Methods
    
    /// Get the active worship service
    private var activeService: WorshipService? {
        services.first { $0.isActive }
    }
    
    /// Check if a hymn is in the active service
    private func isHymnInActiveService(_ hymn: Hymn) -> Bool {
        guard let activeService = activeService else { return false }
        return serviceHymns.contains { serviceHymn in
            serviceHymn.hymnId == hymn.id && serviceHymn.serviceId == activeService.id
        }
    }
    
    /// Get the position of a hymn in the active service
    private func getHymnPositionInService(_ hymn: Hymn) -> Int? {
        guard let activeService = activeService else { return nil }
        let serviceHymnsForActive = serviceHymns
            .filter { $0.serviceId == activeService.id }
            .sorted { $0.order < $1.order }
        
        for (index, serviceHymn) in serviceHymnsForActive.enumerated() {
            if serviceHymn.hymnId == hymn.id {
                return index + 1 // 1-based indexing for display
            }
        }
        return nil
    }
    
    /// Add a hymn to the active service
    private func addToService(_ hymn: Hymn) {
        guard let activeService = activeService else {
            // Create today's service if none exists
            Task {
                let result = await serviceOperations.createTodaysService()
                switch result {
                case .success(let service):
                    let setResult = await serviceOperations.setActiveService(service)
                    if case .success = setResult {
                        let addResult = await serviceOperations.addHymnToService(hymnId: hymn.id, service: service)
                        if case .failure(let error) = addResult {
                            print("Failed to add hymn to service: \(error)")
                        }
                    } else if case .failure(let error) = setResult {
                        print("Failed to set active service: \(error)")
                    }
                case .failure(let error):
                    print("Failed to create today's service: \(error)")
                }
            }
            return
        }
        
        Task {
            let result = await serviceOperations.addHymnToService(hymnId: hymn.id, service: activeService)
            if case .failure(let error) = result {
                print("Failed to add hymn to service: \(error)")
            }
        }
    }
    
    /// Remove a hymn from the active service
    private func removeFromService(_ hymn: Hymn) {
        guard let activeService = activeService else { return }
        
        Task {
            let result = await serviceOperations.removeHymnFromService(hymnId: hymn.id, service: activeService)
            if case .failure(let error) = result {
                print("Failed to remove hymn from service: \(error)")
            }
        }
    }
    
    // MARK: - Service Management Bar Actions
    
    /// Show confirmation dialog for clearing all hymns
    private func clearAllHymns() {
        showingClearAllConfirmation = true
    }
    
    /// Actually clear all hymns from the active service
    private func performClearAllHymns() {
        guard let activeService = activeService else { return }
        
        Task {
            let result = await serviceOperations.clearService(activeService)
            if case .failure(let error) = result {
                print("Failed to clear service: \(error)")
            }
        }
    }
    
    /// Show confirmation dialog for completing service
    private func completeService() {
        showingCompleteServiceConfirmation = true
    }
    
    /// Actually complete the current service
    private func performCompleteService() {
        guard let activeService = activeService else { return }
        
        Task {
            // Mark service as inactive/completed
            activeService.setActive(false)
            
            // Save the context to persist the change
            do {
                try context.save()
                print("Service completed successfully")
                
                // Show brief success feedback
                await MainActor.run {
                    showServiceCompletedSuccess = true
                    // Hide success message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showServiceCompletedSuccess = false
                    }
                }
            } catch {
                print("Failed to complete service: \(error)")
            }
        }
    }
    
    /// Toggle service management mode from the service bar
    private func toggleServiceManagement() {
        isServiceManagementMode.toggle()
    }
    
    /// Create a new service (typically after completing previous one)
    private func createNewService() {
        Task {
            let result = await serviceOperations.createTodaysService()
            switch result {
            case .success(let service):
                let setResult = await serviceOperations.setActiveService(service)
                if case .failure(let error) = setResult {
                    print("Failed to set new service as active: \(error)")
                }
            case .failure(let error):
                print("Failed to create new service: \(error)")
            }
        }
    }
    
    var filteredHymns: [Hymn] {
        // First determine the base hymn list based on sort option
        let baseHymns: [Hymn]
        if sortOption == .service {
            // Service filter mode - show only service hymns
            if let activeService = activeService {
                // When in reorder mode, maintain service order
                if isReorderMode {
                    let serviceHymnsSorted = serviceHymns
                        .filter { $0.serviceId == activeService.id }
                        .sorted { $0.order < $1.order }
                    baseHymns = serviceHymnsSorted.compactMap { serviceHymn in
                        hymns.first { $0.id == serviceHymn.hymnId }
                    }
                } else {
                    let serviceHymnIds = serviceHymns
                        .filter { $0.serviceId == activeService.id }
                        .map { $0.hymnId }
                    baseHymns = hymns.filter { hymn in
                        serviceHymnIds.contains(hymn.id)
                    }
                }
            } else {
                baseHymns = [] // No active service, show empty list
            }
        } else {
            // Regular mode - show all hymns
            baseHymns = hymns
        }
        
        // Then apply search filter
        let filtered: [Hymn]
        if searchText.isEmpty {
            filtered = baseHymns
        } else {
            filtered = baseHymns.filter { hymn in
                let searchQuery = searchText.lowercased()
                // Search in title
                if hymn.title.lowercased().contains(searchQuery) {
                    return true
                }
                // Search in song number if present
                if let number = hymn.songNumber,
                   String(number).contains(searchQuery) {
                    return true
                }
                // Search in lyrics if present
                if let lyrics = hymn.lyrics,
                   lyrics.lowercased().contains(searchQuery) {
                    return true
                }
                // Search in author if present
                if let author = hymn.author,
                   author.lowercased().contains(searchQuery) {
                    return true
                }
                return false
            }
        }
        
        // Skip sorting in reorder mode to maintain order
        if isReorderMode && sortOption == .service {
            return filtered
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
            // Service hymns are already ordered by service order when not in reorder mode
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider above search bar
            Divider()
            
            // Toolbar section with icons (aligned and colored like Song tab)
            HStack(spacing: 24) {
                Spacer()
                
                // Add Hymn Button
                Button(action: {
                    let hymn = Hymn(title: "")
                    context.insert(hymn)
                    newHymn = hymn
                    selected = hymn
                    showingEdit = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text(NSLocalizedString("btn.add", comment: "Add button"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(NSLocalizedString("accessibility.add_new_hymn", comment: "Add new hymn accessibility"))
                
                // Import Button
                Button(action: {
                    importType = .auto
                    currentImportType = .auto
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                        Text(NSLocalizedString("btn.import", comment: "Import button"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(NSLocalizedString("accessibility.import_hymns", comment: "Import hymns accessibility"))
                
                // Export Menu
                Menu {
                    Button(NSLocalizedString("export.selected", comment: "Export selected button")) {
                        if let hymn = selected {
                            selectedHymnsForExport = [hymn.id]
                            showingExportSelection = true
                        }
                    }
                    .disabled(selected == nil)
                    Button(NSLocalizedString("export.multiple", comment: "Export multiple button")) {
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    Button(NSLocalizedString("export.all", comment: "Export all button")) {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    Button(NSLocalizedString("export.large_collection", comment: "Export large collection button")) {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                        Text(NSLocalizedString("btn.export", comment: "Export button"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(NSLocalizedString("accessibility.export_selected", comment: "Export hymns accessibility"))
                
                // Manage Menu
                Menu {
                    Button(isMultiSelectMode ? NSLocalizedString("multiselect.exit", comment: "Exit multi-select") : NSLocalizedString("multiselect.mode", comment: "Multi-select mode")) {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedHymnsForDelete.removeAll()
                        }
                    }
                    .foregroundColor(isMultiSelectMode ? .orange : .blue)
                    if isMultiSelectMode {
                        Divider()
                        Button(NSLocalizedString("btn.select_all", comment: "Select all button")) {
                            selectedHymnsForDelete = Set(hymns.map { $0.id })
                        }
                        .disabled(hymns.isEmpty)
                        Button(NSLocalizedString("btn.deselect_all", comment: "Deselect all button")) {
                            selectedHymnsForDelete.removeAll()
                        }
                        .disabled(selectedHymnsForDelete.isEmpty)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title)
                        Text(NSLocalizedString("btn.manage", comment: "Manage button"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(NSLocalizedString("accessibility.manage_mode", comment: "Manage selection mode accessibility"))
                
                // Help Button
                // Removed as requested
                // Button(action: {
                //     showingImportHelp = true
                // }) {
                //     VStack(spacing: 4) {
                //         Image(systemName: "questionmark.circle")
                //             .font(.title)
                //         Text("Help")
                //             .font(.caption)
                //             .foregroundColor(.secondary)
                //     }
                // }
                // .buttonStyle(PlainButtonStyle())
                // .help("Show import-file help")
                
                // Service Management Mode Toggle Button
                Button(action: {
                    isServiceManagementMode.toggle()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: isServiceManagementMode ? "music.note.list" : "music.note")
                            .font(.title)
                            .foregroundColor(isServiceManagementMode ? .orange : .primary)
                        Text(isServiceManagementMode ? NSLocalizedString("service.management.exit", comment: "Exit service management") : NSLocalizedString("service.management.enter", comment: "Enter service management"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(isServiceManagementMode ? "Exit service management mode" : "Enter service management mode")
                
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Service Management Bar (shown when service exists) or New Service Prompt
            if let activeService = activeService {
                let serviceHymnCount = serviceHymns.filter { $0.serviceId == activeService.id }.count
                
                ServiceManagementBar(
                    activeService: activeService,
                    hymnCount: serviceHymnCount,
                    isCollapsed: $isServiceBarCollapsed,
                    onClearAll: clearAllHymns,
                    onCompleteService: completeService,
                    onReorderToggle: {
                        // Switch to service sort and toggle reorder mode
                        sortOption = .service
                        isReorderMode.toggle()
                    },
                    onManageToggle: toggleServiceManagement
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Divider()
            } else {
                // New Service Prompt (when no active service) or Success Message
                if showServiceCompletedSuccess {
                    ServiceCompletedMessage()
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                } else {
                    NewServicePrompt(
                        onCreateService: createNewService
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                
                Divider()
            }
            
            // Search bar (disabled in reorder mode or service management mode)
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .disabled(isReorderMode || isServiceManagementMode)
                .opacity((isReorderMode || isServiceManagementMode) ? 0.5 : 1.0)
            
            // Sorting options (disabled in reorder mode or service management mode)
            if !isReorderMode && !isServiceManagementMode {
                Picker(NSLocalizedString("sort.by", comment: "Sort by picker"), selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option as SortOption)
                    }
                }
                .onChange(of: sortOption) { oldValue, newValue in
                    // Exit reorder mode when switching away from service sort
                    if newValue != .service && isReorderMode {
                        isReorderMode = false
                    }
                    // Exit service management mode when switching to service sort (to avoid confusion)
                    if newValue == .service && isServiceManagementMode {
                        isServiceManagementMode = false
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                Divider()
            }
            
            // Reorder button for service filter mode
            if sortOption == .service && activeService != nil {
                HStack {
                    Spacer()
                    Button(action: {
                        isReorderMode.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isReorderMode ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                                .foregroundColor(isReorderMode ? .orange : .accentColor)
                            Text(isReorderMode ? NSLocalizedString("service.reorder.on", comment: "Exit reorder") : NSLocalizedString("service.reorder.off", comment: "Reorder hymns"))
                                .font(.caption)
                                .foregroundColor(isReorderMode ? .orange : .accentColor)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                Divider()
            }
            
            // Hymns list
            List {
                ForEach(filteredHymns, id: \.id) { hymn in
                    HymnRow(
                        hymn: hymn,
                        isSelected: selected?.id == hymn.id,
                        isMultiSelectMode: isMultiSelectMode,
                        isMarkedForDelete: selectedHymnsForDelete.contains(hymn.id),
                        isInService: isHymnInActiveService(hymn),
                        servicePosition: getHymnPositionInService(hymn),
                        isReorderMode: isReorderMode && sortOption == .service,
                        isServiceManagementMode: isServiceManagementMode,
                        onToggleDelete: {
                            if selectedHymnsForDelete.contains(hymn.id) {
                                selectedHymnsForDelete.remove(hymn.id)
                            } else {
                                selectedHymnsForDelete.insert(hymn.id)
                            }
                        },
                        onSelect: {
                            if !isMultiSelectMode {
                                selected = hymn
                            }
                        },
                        onEdit: {
                            editHymn = hymn
                            selected = hymn
                            showingEdit = true
                        },
                        onDelete: {
                            if isMultiSelectMode {
                                selectedHymnsForDelete.insert(hymn.id)
                                showingBatchDeleteConfirmation = true
                            } else {
                                hymnToDelete = hymn
                                selected = hymn
                                showingDeleteConfirmation = true
                            }
                        },
                        onAddToService: {
                            addToService(hymn)
                        },
                        onRemoveFromService: {
                            removeFromService(hymn)
                        }
                    )
                    .listRowBackground((selected?.id == hymn.id) ? Color.accentColor.opacity(0.06) : Color.clear)
                }
                .onMove(perform: isReorderMode && sortOption == .service ? moveHymns : nil)
            }
            .listStyle(PlainListStyle())
            .environment(\.editMode, isReorderMode && sortOption == .service ? .constant(.active) : .constant(.inactive))
            
            // Footer with total count and service info
            HStack {
                Spacer()
                
                VStack(spacing: 2) {
                    // Show mode-specific instructions
                    if isReorderMode {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Drag hymns to reorder")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else if isServiceManagementMode {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.minus.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("service.management.instructions", comment: "Service management instructions"))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text(String(format: NSLocalizedString("count.hymns_of_total", comment: "Hymns count display"), filteredHymns.count, hymns.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let activeService = activeService {
                        let serviceHymnCount = serviceHymns.filter { $0.serviceId == activeService.id }.count
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                            Text(String(format: NSLocalizedString("service.hymn_count", comment: "Service hymn count"), serviceHymnCount, activeService.displayTitle))
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
        .frame(minWidth: 250)
        .onAppear {
            // Ensure there's always a service available for the user
            ensureServiceExists()
        }
        .alert(NSLocalizedString("service.clear_all_title", comment: "Clear all hymns title"), isPresented: $showingClearAllConfirmation) {
            Button(NSLocalizedString("btn.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("service.clear_all", comment: "Clear all"), role: .destructive) {
                performClearAllHymns()
            }
        } message: {
            Text(NSLocalizedString("service.clear_all_message", comment: "Clear all confirmation message"))
        }
        .alert(NSLocalizedString("service.complete_title", comment: "Complete service title"), isPresented: $showingCompleteServiceConfirmation) {
            Button(NSLocalizedString("btn.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("service.complete", comment: "Complete"), role: .destructive) {
                performCompleteService()
            }
        } message: {
            Text(NSLocalizedString("service.complete_message", comment: "Complete service confirmation message"))
        }
    }
    
    /// Ensure there's an active service available, creating one if needed
    private func ensureServiceExists() {
        if activeService == nil {
            Task {
                if let existingService = await serviceOperations.ensureTodaysServiceExists() {
                    // Service already exists or was created successfully
                    return
                }
                
                // If that fails, try creating a basic service
                let result = await serviceOperations.createTodaysService()
                if case .success(let service) = result {
                    _ = await serviceOperations.setActiveService(service)
                }
            }
        }
    }
    
    /// Handle reordering hymns in the service
    private func moveHymns(from source: IndexSet, to destination: Int) {
        guard sortOption == .service, 
              let activeService = activeService,
              let sourceIndex = source.first else { return }
        
        // Optimized reordering - only handle single item moves for better performance
        let adjustedDestination = destination > sourceIndex ? destination - 1 : destination
        
        Task {
            let result = await serviceOperations.reorderServiceHymns(
                service: activeService,
                from: sourceIndex,
                to: adjustedDestination
            )
            
            if case .failure(let error) = result {
                print("Failed to reorder hymns: \(error)")
                // Could add user-visible error feedback here if needed
            }
        }
    }
    
}

// New Service Prompt for when no active service exists
struct NewServicePrompt: View {
    let onCreateService: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.house")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("service.no_active_title", comment: "No active service title"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(NSLocalizedString("service.no_active_message", comment: "No active service message"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onCreateService) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                        Text(NSLocalizedString("service.new_service", comment: "New service"))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// Service Completed Success Message
struct ServiceCompletedMessage: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("service.completed_success_title", comment: "Service completed title"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(NSLocalizedString("service.completed_success_message", comment: "Service completed message"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// Service Management Bar for quick service actions
struct ServiceManagementBar: View {
    let activeService: WorshipService?
    let hymnCount: Int
    @Binding var isCollapsed: Bool
    
    let onClearAll: () -> Void
    let onCompleteService: () -> Void
    let onReorderToggle: () -> Void
    let onManageToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let service = activeService {
                // Service header bar
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Text(service.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(hymnCount) \(hymnCount == 1 ? NSLocalizedString("service.hymn_single", comment: "Single hymn") : NSLocalizedString("service.hymn_plural", comment: "Multiple hymns"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !isCollapsed {
                            Text(DateFormatter.localizedString(from: service.date, dateStyle: .medium, timeStyle: .none))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Collapse/Expand button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Service actions (when expanded)
                if !isCollapsed {
                    HStack(spacing: 12) {
                        // Clear All button
                        Button(action: onClearAll) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                Text(NSLocalizedString("service.clear_all", comment: "Clear all hymns"))
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Complete Service button
                        Button(action: onCompleteService) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                Text(NSLocalizedString("service.complete", comment: "Complete service"))
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Quick Manage button
                        Button(action: onManageToggle) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.minus.circle")
                                    .font(.caption)
                                Text(NSLocalizedString("service.quick_manage", comment: "Quick manage"))
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .background(Color(.systemGray6))
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Custom SearchBar to ensure immediate updates
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)
            
            TextField(NSLocalizedString("search.placeholder", comment: "Search placeholder"), text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.body)
                // Add these modifiers to ensure immediate updates
                .onChange(of: text) { oldValue, newValue in
                    // Force immediate update
                    text = newValue
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// Separate view for hymn row to reduce type-checking complexity
struct HymnRow: View {
    let hymn: Hymn
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let isMarkedForDelete: Bool
    let isInService: Bool
    let servicePosition: Int?
    let isReorderMode: Bool
    let isServiceManagementMode: Bool
    let onToggleDelete: () -> Void
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddToService: () -> Void
    let onRemoveFromService: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Show appropriate icon based on mode
            if isMultiSelectMode {
                Image(systemName: isMarkedForDelete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isMarkedForDelete ? .blue : .gray)
                    .onTapGesture {
                        onToggleDelete()
                    }
            } else if isReorderMode {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.secondary)
            } else if isServiceManagementMode {
                // Service management mode: show add/remove buttons
                if isInService {
                    // Remove from service button
                    Button(action: onRemoveFromService) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Add to service button
                    Button(action: onAddToService) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(hymn.title)
                    .font(.headline)
                    .tag(hymn)
                
                HStack(spacing: 8) {
                    if let number = hymn.songNumber {
                        Text("#\(number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    if let key = hymn.musicalKey {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    if let author = hymn.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    // Service indicator
                    if isInService {
                        HStack(spacing: 2) {
                            Image(systemName: "music.note")
                                .font(.caption2)
                            if let position = servicePosition {
                                Text("\(position)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                } else if isServiceManagementMode {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.05))
                }
            }
        )
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else if isServiceManagementMode {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                }
            }
        )
        .contextMenu {
            // Don't show context menu in reorder mode or service management mode
            if !isReorderMode && !isServiceManagementMode {
                // Service actions
                if isInService {
                    Button(NSLocalizedString("service.remove_from_service", comment: "Remove from service")) {
                        onRemoveFromService()
                    }
                } else {
                    Button(NSLocalizedString("service.add_to_service", comment: "Add to service")) {
                        onAddToService()
                    }
                }
                
                Divider()
                
                // Standard actions
                Button(NSLocalizedString("btn.edit", comment: "Edit button")) {
                    onEdit()
                }
                Divider()
                Button(NSLocalizedString("btn.delete", comment: "Delete button"), role: .destructive) {
                    onDelete()
                }
            }
        }
    }
} 
