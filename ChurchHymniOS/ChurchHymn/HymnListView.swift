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
    @State private var showServiceFilter = false
    @State private var isReorderMode = false
    
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
    
    enum SortOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case number = "Number"
        case key = "Key"
        case author = "Author"
        
        var id: String { self.rawValue }
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
    
    var filteredHymns: [Hymn] {
        // First apply service filter if active
        let serviceFiltered: [Hymn]
        if showServiceFilter {
            if let activeService = activeService {
                // When in reorder mode, maintain service order
                if isReorderMode {
                    let serviceHymnsSorted = serviceHymns
                        .filter { $0.serviceId == activeService.id }
                        .sorted { $0.order < $1.order }
                    serviceFiltered = serviceHymnsSorted.compactMap { serviceHymn in
                        hymns.first { $0.id == serviceHymn.hymnId }
                    }
                } else {
                    let serviceHymnIds = serviceHymns
                        .filter { $0.serviceId == activeService.id }
                        .map { $0.hymnId }
                    serviceFiltered = hymns.filter { hymn in
                        serviceHymnIds.contains(hymn.id)
                    }
                }
            } else {
                serviceFiltered = [] // No active service, show empty list
            }
        } else {
            serviceFiltered = hymns
        }
        
        // Then apply search filter
        let filtered: [Hymn]
        if searchText.isEmpty {
            filtered = serviceFiltered
        } else {
            filtered = serviceFiltered.filter { hymn in
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
        if isReorderMode && showServiceFilter {
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
        case .author:
            return filtered.sorted {
                ($0.author ?? "").localizedCaseInsensitiveCompare($1.author ?? "") == .orderedAscending
            }
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
                
                // Service Filter Toggle with integrated reorder option
                Button(action: {
                    if showServiceFilter && activeService != nil {
                        // If already in service mode, toggle reorder
                        isReorderMode.toggle()
                    } else {
                        // Switch to service mode
                        showServiceFilter.toggle()
                        isReorderMode = false
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: getServiceButtonIcon())
                            .font(.title)
                            .foregroundColor(getServiceButtonColor())
                        Text(getServiceButtonText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(getServiceButtonHelp())
                .contextMenu {
                    if showServiceFilter && activeService != nil {
                        Button(action: {
                            showServiceFilter = false
                            isReorderMode = false
                        }) {
                            Label("Show All Hymns", systemImage: "music.note")
                        }
                        
                        Button(action: {
                            isReorderMode.toggle()
                        }) {
                            Label(isReorderMode ? "Exit Reorder" : "Reorder Hymns", 
                                  systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Search bar (disabled in reorder mode)
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .disabled(isReorderMode)
                .opacity(isReorderMode ? 0.5 : 1.0)
            
            // Sorting options (disabled in reorder mode)
            if !isReorderMode {
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
                        isReorderMode: isReorderMode && showServiceFilter,
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
                .onMove(perform: isReorderMode && showServiceFilter ? moveHymns : nil)
            }
            .listStyle(PlainListStyle())
            .environment(\.editMode, isReorderMode && showServiceFilter ? .constant(.active) : .constant(.inactive))
            
            // Footer with total count and service info
            HStack {
                Spacer()
                
                VStack(spacing: 2) {
                    // Show reorder instructions when in reorder mode
                    if isReorderMode {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("Drag hymns to reorder")
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
        guard showServiceFilter, 
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
    
    // MARK: - Service Button Helper Methods
    
    private func getServiceButtonIcon() -> String {
        if isReorderMode {
            return "arrow.up.arrow.down.circle.fill"
        } else if showServiceFilter {
            return "music.note.list"
        } else {
            return "music.note"
        }
    }
    
    private func getServiceButtonColor() -> Color {
        if isReorderMode {
            return .orange
        } else if showServiceFilter {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private func getServiceButtonText() -> String {
        if isReorderMode {
            return NSLocalizedString("service.reorder.on", comment: "Reorder mode on")
        } else if showServiceFilter {
            return NSLocalizedString("service.filter.on", comment: "Service filter on")
        } else {
            return NSLocalizedString("service.filter.off", comment: "Service filter off")
        }
    }
    
    private func getServiceButtonHelp() -> String {
        if isReorderMode {
            return "Tap to exit reorder mode, right-click for options"
        } else if showServiceFilter {
            return "Tap to reorder service hymns, right-click for options"
        } else {
            return "Tap to show today's service hymns"
        }
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
                }
            }
        )
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
        )
        .contextMenu {
            // Don't show context menu in reorder mode
            if !isReorderMode {
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
