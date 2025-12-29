import SwiftUI
import SwiftData

struct HymnToolbar {
    let hymns: [Hymn]
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var showingEdit: Bool
    @Binding var newHymn: Hymn?
    @Binding var importType: ImportType?
    @Binding var currentImportType: ImportType?
    @Binding var selectedHymnsForExport: Set<UUID>
    @Binding var showingExportSelection: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    
    let context: ModelContext
    let onPresent: (Hymn) -> Void
    
    func createToolbar(openWindow: OpenWindowAction) -> some ToolbarContent {
        Group {
            ToolbarItemGroup(placement: .navigation) {
                // Play button - prominent placement
                Button(action: {
                    if let hymn = selected {
                        onPresent(hymn)
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("Present")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(selected == nil)
                .help("Present selected hymn")
                
                // Add Hymn button - prominent placement
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
                            .foregroundColor(.blue)
                        Text("Add")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .help("Add new hymn")
                
                // Import button - prominent placement
                Button(action: {
                    importType = .auto
                    currentImportType = .auto
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                        Text("Import")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .help("Import hymns from text or JSON files")
                
                // Edit button - prominent placement
                Button(action: {
                    showingEdit = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(selected == nil)
                .help("Edit selected hymn")
                
                // Delete button - prominent placement
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
                    VStack(spacing: 4) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("Delete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isMultiSelectMode ? selectedHymnsForDelete.isEmpty : selected == nil)
                .help(isMultiSelectMode ? "Delete selected hymns" : "Delete selected hymn")
                
                // Select All button - only visible in multi-select mode
                if isMultiSelectMode {
                    let allHymnIds = Set(hymns.map { $0.id })
                    let isAllSelected = !hymns.isEmpty && selectedHymnsForDelete == allHymnIds
                    
                    Button(action: {
                        if isAllSelected {
                            selectedHymnsForDelete.removeAll()
                        } else {
                            selectedHymnsForDelete = allHymnIds
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: isAllSelected ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text(isAllSelected ? "Deselect All" : "Select All")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(hymns.isEmpty)
                    .help(isAllSelected ? "Deselect all hymns" : "Select all hymns")
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Help icon button has been removed from the left column toolbar.

                // Export Menu
                Menu("Export") {
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
                    .disabled(hymns.isEmpty)
                    
                    Button("Export All") { 
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    
                    Button("Export Large Collection") { 
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    .help("Use streaming for large collections (>1000 hymns)")
                }
                
                // Management Menu
                Menu("Manage") {
                    Button(isMultiSelectMode ? "Exit Multi-Select" : "Multi-Select") {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedHymnsForDelete.removeAll()
                        }
                    }
                    .foregroundColor(isMultiSelectMode ? .orange : .blue)
                    
                    if isMultiSelectMode {
                        Divider()
                        Button("Select All") {
                            selectedHymnsForDelete = Set(hymns.map { $0.id })
                        }
                        .disabled(hymns.isEmpty)
                        
                        Button("Deselect All") {
                            selectedHymnsForDelete.removeAll()
                        }
                        .disabled(selectedHymnsForDelete.isEmpty)
                    }
                }
            }
        }
    }
} 

struct HymnToolbarView: View {
    let hymns: [Hymn]
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var showingEdit: Bool
    @Binding var newHymn: Hymn?
    @Binding var importType: ImportType?
    @Binding var currentImportType: ImportType?
    @Binding var selectedHymnsForExport: Set<UUID>
    @Binding var showingExportSelection: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    @Binding var lyricsFontSize: CGFloat
    let context: ModelContext
    let openWindow: OpenWindowAction
    let onPresent: (Hymn) -> Void
    
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager

    var body: some View {
        HStack(spacing: 40) { // Evenly space icons
            Spacer()
            // Present Button
            Button(action: {
                if let hymn = selected {
                    onPresent(hymn)
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("Present")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(selected == nil)
            .help("Present selected hymn")

            // External Display Button
            ExternalDisplayButton(selectedHymn: selected)

            // Edit Button
            Button(action: {
                showingEdit = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(selected == nil)
            .help("Edit selected hymn")

            // Font Size Control
            FontSizeSliderButton(lyricsFontSize: $lyricsFontSize)
            
            // External Display Preview Settings (iPad only)
            if UIDevice.current.userInterfaceIdiom == .pad && externalDisplayManager.state != .disconnected {
                ExternalDisplayPreviewSettingsButton()
            }

            // Delete Button (added before Help)
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
                VStack(spacing: 4) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("Delete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isMultiSelectMode ? selectedHymnsForDelete.isEmpty : selected == nil)
            .help(isMultiSelectMode ? "Delete selected hymns" : "Delete selected hymn")

            // Help icon (for iPad)
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button {
                    openWindow(id: "importHelp")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.title)
                        Text("Help")
                            .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .help("Show import-file help")
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
} 

struct ExternalDisplayButton: View {
    let selectedHymn: Hymn?
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: buttonAction) {
            VStack(spacing: 4) {
                Image(systemName: buttonIcon)
                    .font(.title)
                    .foregroundColor(buttonColor)
                Text(buttonText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isButtonDisabled)
        .help(buttonHelpText)
        .alert("External Display Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var buttonIcon: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "tv.slash"
        case .connected:
            return "tv"
        case .presenting:
            return "tv.fill"
        case .worshipMode:
            return "tv.fill"
        case .worshipPresenting:
            return "tv.fill"
        }
    }
    
    private var buttonColor: Color {
        switch externalDisplayManager.state {
        case .disconnected:
            return .gray
        case .connected:
            return .green
        case .presenting:
            return .orange
        case .worshipMode:
            return .purple
        case .worshipPresenting:
            return .orange
        }
    }
    
    private var buttonText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "No Display"
        case .connected:
            return "External"
        case .presenting:
            return "Stop External"
        case .worshipMode:
            return "Worship"
        case .worshipPresenting:
            return "Stop Hymn"
        }
    }
    
    private var buttonHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return "No external display connected"
        case .connected:
            return "Present to external display"
        case .presenting:
            return "Stop external presentation"
        case .worshipMode:
            return "Present hymn in worship session"
        case .worshipPresenting:
            return "Stop hymn presentation (return to worship background)"
        }
    }
    
    private var isButtonDisabled: Bool {
        switch externalDisplayManager.state {
        case .disconnected:
            return true
        case .connected:
            return selectedHymn == nil
        case .presenting:
            return false
        case .worshipMode:
            return selectedHymn == nil
        case .worshipPresenting:
            return false
        }
    }
    
    private func buttonAction() {
        switch externalDisplayManager.state {
        case .disconnected:
            break
        case .connected:
            startExternalPresentation()
        case .presenting:
            externalDisplayManager.stopPresentation()
        case .worshipMode:
            startWorshipHymnPresentation()
        case .worshipPresenting:
            stopWorshipHymnPresentation()
        }
    }
    
    private func startExternalPresentation() {
        guard let hymn = selectedHymn else { return }
        
        do {
            try externalDisplayManager.startPresentation(hymn: hymn)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func startWorshipHymnPresentation() {
        guard let hymn = selectedHymn else { return }
        
        Task {
            do {
                try await externalDisplayManager.presentOrSwitchToHymn(hymn)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func stopWorshipHymnPresentation() {
        Task {
            await externalDisplayManager.stopHymnInWorshipMode()
        }
    }
}

struct FontSizeSliderButton: View {
    @Binding var lyricsFontSize: CGFloat
    @State private var showSlider = false

    var body: some View {
        Button(action: { showSlider.toggle() }) {
            VStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Font Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .popover(isPresented: $showSlider) {
            VStack {
                Text("Font Size: \(Int(lyricsFontSize))")
                    .font(.headline)
                Slider(
                    value: $lyricsFontSize,
                    in: 8...32,
                    step: 1
                )
                .padding()
            }
            .frame(width: 220)
            .padding()
        }
        .help("Adjust font size")
    }
} 
