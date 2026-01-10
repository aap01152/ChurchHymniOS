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
                        Text(NSLocalizedString("btn.present", comment: "Present"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(selected == nil)
                .help(NSLocalizedString("help.present_selected_hymn", comment: "Present selected hymn help"))
                
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
                        Text(NSLocalizedString("btn.add", comment: "Add"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .help(NSLocalizedString("help.add_new_hymn", comment: "Add new hymn help"))
                
                // Import button - prominent placement
                Button(action: {
                    importType = .auto
                    currentImportType = .auto
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                        Text(NSLocalizedString("btn.import", comment: "Import"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .help(NSLocalizedString("help.import_hymns_text_json", comment: "Import hymns help"))
                
                // Edit button - prominent placement
                Button(action: {
                    showingEdit = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("btn.edit", comment: "Edit"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(selected == nil)
                .help(NSLocalizedString("help.edit_selected_hymn", comment: "Edit selected hymn help"))
                
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
                        Text(NSLocalizedString("btn.delete", comment: "Delete"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isMultiSelectMode ? selectedHymnsForDelete.isEmpty : selected == nil)
                .help(isMultiSelectMode
                    ? NSLocalizedString("help.delete_selected_hymns", comment: "Delete selected hymns help")
                    : NSLocalizedString("help.delete_selected_hymn", comment: "Delete selected hymn help")
                )
                
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
                            Text(isAllSelected ? NSLocalizedString("btn.deselect_all", comment: "Deselect All") : NSLocalizedString("btn.select_all", comment: "Select All"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(hymns.isEmpty)
                    .help(isAllSelected
                        ? NSLocalizedString("help.deselect_all_hymns", comment: "Deselect all hymns help")
                        : NSLocalizedString("help.select_all_hymns", comment: "Select all hymns help")
                    )
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Help icon button has been removed from the left column toolbar.

                // Export Menu
                Menu(NSLocalizedString("btn.export", comment: "Export")) {
                    Button(NSLocalizedString("export.selected", comment: "Export selected")) {
                        if let hymn = selected {
                            selectedHymnsForExport = [hymn.id]
                            showingExportSelection = true
                        }
                    }
                    .disabled(selected == nil)
                    
                    Button(NSLocalizedString("export.multiple", comment: "Export multiple")) {
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    
                    Button(NSLocalizedString("export.all", comment: "Export all")) {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    
                    Button(NSLocalizedString("export.large_collection", comment: "Export large collection")) {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    .help(NSLocalizedString("help.export_large_collection", comment: "Use streaming for large collections"))
                }
                
                // Management Menu
                Menu(NSLocalizedString("btn.manage", comment: "Manage")) {
                    Button(isMultiSelectMode
                        ? NSLocalizedString("multiselect.exit", comment: "Exit multi-select")
                        : NSLocalizedString("multiselect.mode", comment: "Multi-select")
                    ) {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedHymnsForDelete.removeAll()
                        }
                    }
                    .foregroundColor(isMultiSelectMode ? .orange : .blue)
                    
                    if isMultiSelectMode {
                        Divider()
                        Button(NSLocalizedString("btn.select_all", comment: "Select All")) {
                            selectedHymnsForDelete = Set(hymns.map { $0.id })
                        }
                        .disabled(hymns.isEmpty)
                        
                        Button(NSLocalizedString("btn.deselect_all", comment: "Deselect All")) {
                            selectedHymnsForDelete.removeAll()
                        }
                        .disabled(selectedHymnsForDelete.isEmpty)
                    }
                }
            }
        }
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
        .alert(NSLocalizedString("alert.external_display_error", comment: "External Display Error"), isPresented: $showingErrorAlert) {
            Button(NSLocalizedString("btn.ok", comment: "OK")) { }
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
            return NSLocalizedString("external.no_display", comment: "No external display available")
        case .connected:
            return NSLocalizedString("external.button.external", comment: "External button")
        case .presenting:
            return NSLocalizedString("external.button.stop_external", comment: "Stop external")
        case .worshipMode:
            return NSLocalizedString("external.button.worship", comment: "Worship")
        case .worshipPresenting:
            return NSLocalizedString("external.button.stop_hymn", comment: "Stop hymn")
        }
    }
    
    private var buttonHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected:
            return NSLocalizedString("help.external.no_display_connected", comment: "No external display connected")
        case .connected:
            return NSLocalizedString("help.external.present_to_external", comment: "Present to external display")
        case .presenting:
            return NSLocalizedString("help.external.stop_external_presentation", comment: "Stop external presentation")
        case .worshipMode:
            return NSLocalizedString("help.external.present_in_worship", comment: "Present hymn in worship session")
        case .worshipPresenting:
            return NSLocalizedString("help.external.stop_hymn_return_worship", comment: "Stop hymn presentation and return to worship background")
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
                Text(NSLocalizedString("display.font_size", comment: "Font Size"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .popover(isPresented: $showSlider) {
            VStack {
                Text(String(format: NSLocalizedString("display.font_size_value", comment: "Font Size: %d"), Int(lyricsFontSize)))
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
        .help(NSLocalizedString("help.adjust_font_size", comment: "Adjust font size"))
    }
} 

struct HymnToolbarView: View {
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
                    .help(NSLocalizedString("help.present_selected_hymn", comment: "Present selected hymn help"))
                    
                    // Add Button
                    UniformToolbarButton(
                        icon: "plus.circle.fill",
                        text: NSLocalizedString("btn.add", comment: "Add"),
                        color: .blue,
                        action: onAddNew
                    )
                    .help(NSLocalizedString("help.add_new_hymn", comment: "Add new hymn help"))
                    
                    // Edit Button
                    UniformToolbarButton(
                        icon: "pencil.circle.fill",
                        text: NSLocalizedString("btn.edit", comment: "Edit"),
                        color: selected == nil ? .gray : .orange,
                        action: onEdit,
                        isEnabled: selected != nil
                    )
                    .help(NSLocalizedString("help.edit_selected_hymn", comment: "Edit selected hymn help"))
                    
                    // Delete Button
                    UniformToolbarButton(
                        icon: "trash.circle.fill",
                        text: NSLocalizedString("btn.delete", comment: "Delete"),
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
                    .help(isMultiSelectMode
                        ? NSLocalizedString("help.delete_selected_hymns", comment: "Delete selected hymns help")
                        : NSLocalizedString("help.delete_selected_hymn", comment: "Delete selected hymn help")
                    )
                    
                    // Import Button
                    UniformToolbarButton(
                        icon: "square.and.arrow.down.fill",
                        text: NSLocalizedString("btn.import", comment: "Import"),
                        color: .purple,
                        action: {
                            showingImporter = true
                        }
                    )
                    .help(NSLocalizedString("help.import_hymns_files", comment: "Import hymns from files"))
                    
                    // Export Menu
                    Menu {
                        Button(NSLocalizedString("export.selected", comment: "Export selected")) {
                            if let hymn = selected {
                                selectedHymnsForExport = [hymn.id]
                                showingExportSelection = true
                            }
                        }
                        .disabled(selected == nil)
                        
                        Button(NSLocalizedString("export.multiple", comment: "Export multiple")) {
                            showingExportSelection = true
                        }
                        .disabled(hymnService.hymns.isEmpty)
                        
                        Button(NSLocalizedString("export.all", comment: "Export all")) {
                            selectedHymnsForExport = Set(hymnService.hymns.map { $0.id })
                            showingExportSelection = true
                        }
                        .disabled(hymnService.hymns.isEmpty)
                        
                        Divider()
                        
                        Button(NSLocalizedString("export.help", comment: "Export help")) {
                            helpSystem.showHelp(for: .exportingHymns)
                        }
                    } label: {
                        UniformToolbarButtonContent(
                            icon: "square.and.arrow.up.fill",
                            text: NSLocalizedString("btn.export", comment: "Export"),
                            color: .blue
                        )
                    }
                    .help(NSLocalizedString("help.export_hymns_files", comment: "Export hymns to files"))
                    
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
                            text: NSLocalizedString("display.font_size_multiline", comment: "Font size multiline"),
                            color: .secondary
                        )
                    }
                    .help(NSLocalizedString("help.adjust_font_size", comment: "Adjust font size"))
                    
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
                                text: NSLocalizedString("btn.help", comment: "Help"),
                                color: .secondary
                            )
                        }
                        .help(NSLocalizedString("help.get_contextual_help", comment: "Get contextual help"))
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
        case .connected: return NSLocalizedString("external.button.external", comment: "External button")
        case .presenting: return NSLocalizedString("external.button.stop_external", comment: "Stop external")
        case .worshipMode: return NSLocalizedString("external.button.worship", comment: "Worship")
        case .worshipPresenting: return NSLocalizedString("external.button.stop_hymn", comment: "Stop hymn")
        }
    }
    
    private var externalDisplayHelpText: String {
        switch externalDisplayManager.state {
        case .disconnected: return NSLocalizedString("status.no_external_display", comment: "No external display")
        case .connected: return NSLocalizedString("help.external.present_to_external", comment: "Present to external display")
        case .presenting: return NSLocalizedString("help.external.stop_external_presentation", comment: "Stop external presentation")
        case .worshipMode: return NSLocalizedString("help.external.present_in_worship", comment: "Present hymn in worship session")
        case .worshipPresenting: return NSLocalizedString("help.external.stop_hymn_return_worship", comment: "Stop hymn presentation and return to worship background")
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
