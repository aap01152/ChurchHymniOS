import SwiftUI
import SwiftData

struct HymnListView: View {
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
                .searchable(text: $searchText, prompt: NSLocalizedString("search.placeholder", comment: "Search hymns..."))
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
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.caption2)
                                Text("\(hymnCount) \(hymnCount == 1 ? NSLocalizedString("service.hymn_single", comment: "Single hymn") : NSLocalizedString("service.hymn_plural", comment: "Multiple hymns"))")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if !isCollapsed {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateFormatter.localizedString(from: service.date, dateStyle: .medium, timeStyle: .none))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("Green + buttons add hymns to service")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
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
                                Image(systemName: "plus.circle")
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
    let hasActiveService: Bool
    let onToggleDelete: () -> Void
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddToService: () -> Void
    let onRemoveFromService: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Always show service buttons when there's an active service (unless in special modes)
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
            } else if hasActiveService {
                // Always show service buttons when there's an active service
                if isInService {
                    // Show remove button for hymns in service
                    Button(action: onRemoveFromService) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Remove from service")
                } else {
                    // Show add button for hymns not in service
                    Button(action: onAddToService) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Add to service")
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
                    
                    // Simplified service indicator
                    if isInService {
                        if let position = servicePosition {
                            Text("#\(position)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(8)
                        } else {
                            Text("✓")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
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
