import SwiftUI
import Foundation

/// Centralized help system for ChurchHymn iOS
/// Provides contextual help content and navigation for all app features
@MainActor
final class HelpSystem: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isHelpSheetPresented = false
    @Published var currentHelpTopic: HelpTopic = .overview
    @Published var searchText = ""
    
    // MARK: - Help Content
    
    /// All available help topics organized by category
    static let helpTopics: [HelpCategory: [HelpTopic]] = [
        .gettingStarted: [
            .overview,
            .addingFirstHymn,
            .navigatingInterface,
            .basicPresentation
        ],
        .hymnManagement: [
            .creatingHymns,
            .editingHymns,
            .deletingHymns,
            .searchingHymns,
            .importingHymns,
            .exportingHymns
        ],
        .serviceManagement: [
            .creatingServices,
            .managingServices,
            .addingHymnsToService,
            .reorderingHymns,
            .completingServices
        ],
        .presentation: [
            .basicPresentation,
            .externalDisplay,
            .presentationControls,
            .fontAdjustment
        ],
        .advanced: [
            .multiSelect,
            .batchOperations,
            .keyboardShortcuts,
            .troubleshooting
        ]
    ]
    
    /// Filtered help topics based on search
    var filteredTopics: [HelpTopic] {
        if searchText.isEmpty {
            return Self.helpTopics.values.flatMap { $0 }
        }
        
        let searchLower = searchText.lowercased()
        return Self.helpTopics.values.flatMap { $0 }.filter { topic in
            topic.title.lowercased().contains(searchLower) ||
            topic.content.lowercased().contains(searchLower) ||
            topic.keywords.contains { $0.lowercased().contains(searchLower) }
        }
    }
    
    // MARK: - Public Methods
    
    /// Show help for a specific topic
    func showHelp(for topic: HelpTopic) {
        currentHelpTopic = topic
        isHelpSheetPresented = true
    }
    
    /// Show general help overview
    func showHelp() {
        currentHelpTopic = .overview
        isHelpSheetPresented = true
    }
    
    /// Get contextual help for current app state
    func getContextualHelp(for context: HelpContext) -> HelpTopic {
        switch context {
        case .emptyHymnList:
            return .addingFirstHymn
        case .hymnSelected:
            return .basicPresentation
        case .multiSelectMode:
            return .multiSelect
        case .serviceManagement:
            return .managingServices
        case .importing:
            return .importingHymns
        case .exporting:
            return .exportingHymns
        case .externalDisplay:
            return .externalDisplay
        }
    }
    
    /// Navigate to related topic
    func navigateToTopic(_ topic: HelpTopic) {
        currentHelpTopic = topic
    }
}

// MARK: - Help Categories

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case hymnManagement = "Hymn Management"
    case serviceManagement = "Service Management"
    case presentation = "Presentation"
    case advanced = "Advanced Features"
    
    var icon: String {
        switch self {
        case .gettingStarted: return "play.circle"
        case .hymnManagement: return "music.note"
        case .serviceManagement: return "calendar"
        case .presentation: return "tv"
        case .advanced: return "gearshape"
        }
    }
    
    var color: Color {
        switch self {
        case .gettingStarted: return .green
        case .hymnManagement: return .blue
        case .serviceManagement: return .orange
        case .presentation: return .purple
        case .advanced: return .red
        }
    }
}

// MARK: - Help Topics

enum HelpTopic: String, CaseIterable, Identifiable {
    case overview
    case addingFirstHymn
    case navigatingInterface
    case creatingHymns
    case editingHymns
    case deletingHymns
    case searchingHymns
    case importingHymns
    case exportingHymns
    case creatingServices
    case managingServices
    case addingHymnsToService
    case reorderingHymns
    case completingServices
    case basicPresentation
    case externalDisplay
    case presentationControls
    case fontAdjustment
    case multiSelect
    case batchOperations
    case keyboardShortcuts
    case troubleshooting
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview: return "ChurchHymn Overview"
        case .addingFirstHymn: return "Adding Your First Hymn"
        case .navigatingInterface: return "Navigating the Interface"
        case .creatingHymns: return "Creating New Hymns"
        case .editingHymns: return "Editing Hymns"
        case .deletingHymns: return "Deleting Hymns"
        case .searchingHymns: return "Searching and Sorting Hymns"
        case .importingHymns: return "Importing Hymns"
        case .exportingHymns: return "Exporting Hymns"
        case .creatingServices: return "Creating Worship Services"
        case .managingServices: return "Managing Services"
        case .addingHymnsToService: return "Adding Hymns to Services"
        case .reorderingHymns: return "Reordering Service Hymns"
        case .completingServices: return "Completing Services"
        case .basicPresentation: return "Presenting Hymns"
        case .externalDisplay: return "Using External Displays"
        case .presentationControls: return "Presentation Controls"
        case .fontAdjustment: return "Adjusting Font Size"
        case .multiSelect: return "Multi-Select Mode"
        case .batchOperations: return "Batch Operations"
        case .keyboardShortcuts: return "Keyboard Shortcuts"
        case .troubleshooting: return "Troubleshooting"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "house"
        case .addingFirstHymn: return "plus.circle"
        case .navigatingInterface: return "map"
        case .creatingHymns: return "note.text.badge.plus"
        case .editingHymns: return "pencil"
        case .deletingHymns: return "trash"
        case .searchingHymns: return "magnifyingglass"
        case .importingHymns: return "square.and.arrow.down"
        case .exportingHymns: return "square.and.arrow.up"
        case .creatingServices: return "calendar.badge.plus"
        case .managingServices: return "calendar"
        case .addingHymnsToService: return "music.note.list"
        case .reorderingHymns: return "list.bullet"
        case .completingServices: return "checkmark.circle"
        case .basicPresentation: return "play.circle"
        case .externalDisplay: return "tv"
        case .presentationControls: return "remote"
        case .fontAdjustment: return "textformat.size"
        case .multiSelect: return "checkmark.circle"
        case .batchOperations: return "square.grid.3x3"
        case .keyboardShortcuts: return "keyboard"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
    
    var category: HelpCategory {
        switch self {
        case .overview, .addingFirstHymn, .navigatingInterface, .basicPresentation:
            return .gettingStarted
        case .creatingHymns, .editingHymns, .deletingHymns, .searchingHymns, .importingHymns, .exportingHymns:
            return .hymnManagement
        case .creatingServices, .managingServices, .addingHymnsToService, .reorderingHymns, .completingServices:
            return .serviceManagement
        case .externalDisplay, .presentationControls, .fontAdjustment:
            return .presentation
        case .multiSelect, .batchOperations, .keyboardShortcuts, .troubleshooting:
            return .advanced
        }
    }
    
    var keywords: [String] {
        switch self {
        case .overview:
            return ["app", "introduction", "start", "begin", "welcome"]
        case .addingFirstHymn:
            return ["new", "create", "add", "first", "hymn", "song"]
        case .navigatingInterface:
            return ["navigate", "interface", "UI", "tabs", "buttons", "menu"]
        case .creatingHymns:
            return ["create", "new", "hymn", "add", "compose", "write"]
        case .editingHymns:
            return ["edit", "modify", "change", "update", "lyrics", "title"]
        case .deletingHymns:
            return ["delete", "remove", "trash", "clear"]
        case .searchingHymns:
            return ["search", "find", "filter", "sort", "order", "browse"]
        case .importingHymns:
            return ["import", "load", "file", "JSON", "text", "upload"]
        case .exportingHymns:
            return ["export", "save", "file", "backup", "share", "download"]
        case .creatingServices:
            return ["service", "worship", "create", "new", "plan"]
        case .managingServices:
            return ["service", "manage", "active", "switch", "list"]
        case .addingHymnsToService:
            return ["service", "add", "hymn", "playlist", "worship"]
        case .reorderingHymns:
            return ["reorder", "move", "arrange", "sequence", "order"]
        case .completingServices:
            return ["complete", "finish", "service", "done", "archive"]
        case .basicPresentation:
            return ["present", "display", "show", "fullscreen", "worship"]
        case .externalDisplay:
            return ["external", "display", "monitor", "screen", "projector", "TV"]
        case .presentationControls:
            return ["controls", "present", "display", "navigation"]
        case .fontAdjustment:
            return ["font", "size", "text", "larger", "smaller", "adjust"]
        case .multiSelect:
            return ["select", "multiple", "bulk", "batch", "choose"]
        case .batchOperations:
            return ["batch", "bulk", "multiple", "mass", "operations"]
        case .keyboardShortcuts:
            return ["keyboard", "shortcuts", "hotkeys", "quick", "keys"]
        case .troubleshooting:
            return ["help", "problem", "issue", "error", "fix", "support"]
        }
    }
    
    var content: String {
        switch self {
        case .overview:
            return """
            Welcome to ChurchHymn iOS! This app helps you manage and present hymns for worship services.
            
            **Key Features:**
            • Create and edit hymns with lyrics, musical keys, and metadata
            • Organize hymns into worship services
            • Present hymns in fullscreen mode
            • Support for external displays
            • Import and export hymn collections
            • Advanced search and sorting capabilities
            
            **Getting Started:**
            1. Add your first hymn using the "+" button
            2. Create a worship service to organize hymns
            3. Present hymns during worship using the "Present" button
            
            Use the help system anytime by tapping the "?" button in the toolbar.
            """
            
        case .addingFirstHymn:
            return """
            **Adding Your First Hymn:**
            
            1. Tap the **"Add"** button (+ icon) in the toolbar
            2. Enter the hymn details:
               • **Title**: The name of the hymn
               • **Lyrics**: Full text with verses separated by blank lines
               • **Author**: Composer or lyricist (optional)
               • **Musical Key**: Key signature (optional)
               • **Song Number**: Traditional hymn number (optional)
            
            3. Tap **"Save"** when finished
            
            **Tips:**
            • Use blank lines to separate verses for better readability
            • Add musical key information for musicians
            • Song numbers help with traditional hymnals
            """
            
        case .navigatingInterface:
            return """
            **Interface Overview:**
            
            **iPad Layout:**
            • **Left Panel**: Hymn list with search and filters
            • **Right Panel**: Selected hymn details and controls
            • **Toolbar**: Main action buttons (Present, Add, Edit, Delete, Import, Export)
            
            **iPhone Layout:**
            • **Library Tab**: Browse and manage hymns
            • **Song Tab**: View selected hymn details
            • **Services Tab**: Manage worship services
            
            **Key Controls:**
            • **Search Bar**: Find hymns quickly
            • **Sort Options**: Order by title, number, key, or service order
            • **External Display Status**: Shows connection to external screens
            """
            
        case .creatingHymns:
            return """
            **Creating New Hymns:**
            
            1. Tap the **"Add"** button in the toolbar
            2. Fill in hymn information:
               • **Title**: Required hymn name
               • **Lyrics**: Verse text (use blank lines between verses)
               • **Author**: Optional composer/author name
               • **Copyright**: Copyright information
               • **Musical Key**: Key signature for musicians
               • **Song Number**: Traditional hymnal number
               • **Tags**: Keywords for organization
               • **Notes**: Additional information
            
            3. Tap **"Save"** to add the hymn to your library
            
            **Best Practices:**
            • Use descriptive titles for easy searching
            • Format lyrics with clear verse separation
            • Include copyright information when known
            """
            
        case .editingHymns:
            return """
            **Editing Existing Hymns:**
            
            **Method 1: From Detail View**
            1. Select a hymn from the list
            2. Tap the **"Edit"** button in the toolbar
            
            **Method 2: From Hymn List**
            1. Tap the menu button (⋯) next to a hymn
            2. Select **"Edit"**
            
            **Making Changes:**
            • Modify any field as needed
            • Use the preview to check formatting
            • Tap **"Save"** to apply changes
            • Tap **"Cancel"** to discard changes
            
            **Note**: Changes are immediately saved to your library.
            """
            
        case .deletingHymns:
            return """
            **Deleting Hymns:**
            
            **Single Hymn:**
            1. Select the hymn to delete
            2. Tap the **"Delete"** button (trash icon) in toolbar
            3. Confirm deletion in the alert dialog
            
            **Multiple Hymns:**
            1. Tap **"Select"** button to enter multi-select mode
            2. Tap hymns to select them (checkmarks appear)
            3. Tap **"Delete Selected"** button
            4. Confirm deletion in the alert dialog
            
            **Important**: Deleted hymns are permanently removed and cannot be recovered unless you have a backup.
            """
            
        case .searchingHymns:
            return """
            **Searching and Sorting:**
            
            **Search Features:**
            • Search by title, author, lyrics, or song number
            • Real-time filtering as you type
            • Case-insensitive matching
            • Searches across all hymn fields
            
            **Sort Options:**
            • **Title**: Alphabetical order
            • **Number**: By song number
            • **Key**: By musical key
            • **Service**: Service order (when service is active)
            
            **Advanced Tips:**
            • Use partial matches (e.g., "amaz" finds "Amazing Grace")
            • Search by author to find all hymns by a composer
            • Use key search to find hymns in specific keys
            """
            
        case .importingHymns:
            return """
            **Importing Hymn Collections:**
            
            1. Tap the **"Import"** button in the toolbar
            2. Select file(s) to import:
               • **JSON files**: Full hymn data with metadata
               • **Text files**: Simple lyrics that will be parsed
               • **Multiple files**: Select several files at once
            
            3. Preview imported hymns:
               • Review hymn titles and content
               • See duplicate detection
               • Resolve any conflicts
            
            4. Confirm import to add hymns to your library
            
            **Supported Formats:**
            • JSON format with hymn objects
            • Plain text files with title and lyrics
            • Auto-detection attempts to parse any text format
            """
            
        case .exportingHymns:
            return """
            **Exporting Hymns:**
            
            **Export Options:**
            • **Export Selected**: Current hymn only
            • **Export Multiple**: Choose specific hymns
            • **Export All**: Complete hymn library
            
            **Export Process:**
            1. Tap **"Export"** in the toolbar
            2. Choose export option from the menu
            3. Select hymns (if choosing multiple)
            4. Choose file format (JSON or Text)
            5. Select save location
            
            **File Formats:**
            • **JSON**: Complete data including metadata
            • **Text**: Simple lyrics-only format
            
            **Uses**: Backup, sharing, migration to other apps
            """
            
        case .creatingServices:
            return """
            **Creating Worship Services:**
            
            1. Tap **"Services"** (iPad) or Services tab (iPhone)
            2. Tap **"New Service"** or **"Create Service"**
            3. Enter service details:
               • **Title**: Service name (e.g., "Sunday Morning")
               • **Date**: Service date
               • **Notes**: Optional description or instructions
            
            4. Tap **"Create"** to save the service
            5. The new service becomes active automatically
            
            **Quick Option:**
            Tap **"Create Today's Service"** for a service with today's date.
            
            **Service Benefits:**
            • Organize hymns for specific worship times
            • Maintain order and flow
            • Track service history
            """
            
        case .managingServices:
            return """
            **Managing Worship Services:**
            
            **Viewing Services:**
            • Active service appears at the top with special highlighting
            • All services listed below with dates and hymn counts
            • Service status indicators show active/completed state
            
            **Service Actions:**
            • **Activate**: Make a different service active
            • **View Details**: See service hymns and information
            • **Add Hymns**: Include hymns in the service
            • **Reorder**: Change hymn sequence
            • **Complete**: Mark service as finished
            
            **Active Service Bar:**
            When a service is active, management controls appear in the hymn list for quick access.
            """
            
        case .addingHymnsToService:
            return """
            **Adding Hymns to Services:**
            
            **From Service Details:**
            1. Open service details
            2. Tap **"Add Hymn"**
            3. Search and select hymns to add
            4. Hymns are added in order selected
            
            **From Hymn List (with active service):**
            • Hymns can be quickly added using service controls
            • Plus buttons appear next to hymns not in service
            • Service filter shows only hymns in active service
            
            **Service Hymn Features:**
            • Automatic ordering (1st, 2nd, 3rd, etc.)
            • Drag to reorder within service
            • Remove individual hymns as needed
            • View service-only filtered list
            """
            
        case .reorderingHymns:
            return """
            **Reordering Service Hymns:**
            
            **In Service Details:**
            1. Open the service details view
            2. Use drag handles to move hymns up/down
            3. Order is saved automatically
            4. Hymn numbers update to reflect new order
            
            **Using Service Sort:**
            1. Set sort option to **"Service"** in hymn list
            2. This shows hymns in service order
            3. Use reorder mode for drag-and-drop
            
            **Best Practices:**
            • Plan opening, middle, and closing hymns
            • Consider musical flow and keys
            • Group thematically related hymns
            • Test the order before worship
            """
            
        case .completingServices:
            return """
            **Completing Services:**
            
            **When to Complete:**
            • After the worship service ends
            • When planning a new service
            • To archive historical services
            
            **How to Complete:**
            1. From active service card, tap **"Complete"** option
            2. Or use service management tools
            3. Confirm completion in dialog
            4. Service is marked as completed and archived
            
            **After Completion:**
            • Service becomes inactive
            • Hymns remain in your library
            • Service history is preserved
            • Can create new active service
            
            **Benefits**: Keeps active services focused and maintains worship history.
            """
            
        case .basicPresentation:
            return """
            **Presenting Hymns:**
            
            **Starting Presentation:**
            1. Select a hymn from the list
            2. Tap the **"Present"** button (play icon)
            3. Hymn displays in fullscreen mode
            4. Swipe or use controls to navigate verses
            
            **Presentation Controls:**
            • **Swipe left/right**: Navigate between verses
            • **Tap screen**: Show/hide navigation controls
            • **Font size**: Adjust text size with +/- buttons
            • **Done**: Exit presentation mode
            
            **Features:**
            • Large, readable text optimized for projection
            • Automatic verse separation
            • Support for external displays
            • Customizable font sizing
            """
            
        case .externalDisplay:
            return """
            **Using External Displays:**
            
            **Connection:**
            • Connect iPad/iPhone to projector or TV via:
              - AirPlay (wireless)
              - Lightning to HDMI adapter
              - USB-C to HDMI (newer devices)
            
            **External Display Features:**
            • **Status Bar**: Shows connection state
            • **Quick Controls**: Start/stop external presentation
            • **Preview**: See what's on external screen
            • **Independent Control**: Device shows controls, external shows hymn
            
            **External Presentation:**
            1. Ensure external display is connected
            2. Select a hymn
            3. Tap external display button in toolbar
            4. Hymn appears on external screen
            5. Use device for navigation and controls
            """
            
        case .presentationControls:
            return """
            **Presentation Control Options:**
            
            **During Presentation:**
            • **Tap Screen**: Toggle control visibility
            • **Swipe Gestures**: Navigate verses
            • **Font Controls**: +/- buttons for text size
            • **Verse Indicators**: Show current position
            
            **External Display Controls:**
            • **Start External**: Begin external presentation
            • **Stop External**: End external presentation
            • **Preview Window**: See external display content
            • **Quick Switch**: Change hymns while presenting
            
            **Navigation:**
            • **Previous/Next**: Move between verses
            • **Jump to Verse**: Direct verse selection
            • **Auto-advance**: Timed progression (if enabled)
            """
            
        case .fontAdjustment:
            return """
            **Adjusting Font Size:**
            
            **In Detail View:**
            1. Use the font size slider in toolbar
            2. Drag to adjust from 12pt to 32pt
            3. Changes apply immediately
            4. Size is saved for future sessions
            
            **During Presentation:**
            1. Tap screen to show controls
            2. Use +/- buttons for fine adjustment
            3. Font size adjusts for readability
            4. Works on both device and external display
            
            **Considerations:**
            • Larger fonts for external projection
            • Smaller fonts for personal reading
            • Consider room size and viewing distance
            • Test readability before worship
            """
            
        case .multiSelect:
            return """
            **Multi-Select Mode:**
            
            **Entering Multi-Select:**
            1. Tap **"Select"** button in hymn list toolbar
            2. Interface changes to show selection controls
            3. Tap hymns to select them (checkmarks appear)
            4. Selected count shows in toolbar
            
            **Multi-Select Actions:**
            • **Select All**: Choose all visible hymns
            • **Deselect All**: Clear all selections
            • **Delete Selected**: Remove multiple hymns
            • **Export Selected**: Export chosen hymns
            
            **Exiting Multi-Select:**
            • Tap **"Done"** to exit mode
            • All selections are cleared
            • Returns to normal browsing mode
            """
            
        case .batchOperations:
            return """
            **Batch Operations:**
            
            **Available Operations:**
            • **Batch Delete**: Remove multiple hymns at once
            • **Batch Export**: Export selected hymns together
            • **Service Operations**: Add/remove multiple hymns from services
            
            **Batch Delete Process:**
            1. Enter multi-select mode
            2. Select hymns to delete
            3. Tap **"Delete Selected"**
            4. Confirm deletion in alert
            5. All selected hymns are removed
            
            **Batch Export Process:**
            1. Select multiple hymns
            2. Choose export format
            3. All selected hymns exported to single file
            4. Useful for creating themed collections
            
            **Safety**: Always confirm batch operations as they affect multiple items.
            """
            
        case .keyboardShortcuts:
            return """
            **Keyboard Shortcuts (iPad):**
            
            **Navigation:**
            • **⌘ + F**: Focus search field
            • **⌘ + N**: Add new hymn
            • **⌘ + E**: Edit selected hymn
            • **⌘ + D**: Delete selected hymn
            • **⌘ + P**: Present selected hymn
            
            **File Operations:**
            • **⌘ + I**: Import hymns
            • **⌘ + S**: Export selected hymn
            • **⌘ + A**: Select all (in multi-select mode)
            
            **Presentation:**
            • **Space**: Start/stop presentation
            • **← →**: Navigate verses during presentation
            • **⌘ + +/-**: Adjust font size
            • **Escape**: Exit presentation mode
            
            **Services:**
            • **⌘ + R**: Open service management
            • **⌘ + T**: Create new service
            """
            
        case .troubleshooting:
            return """
            **Common Issues and Solutions:**
            
            **Import Problems:**
            • **File not recognized**: Check file format (JSON or text)
            • **Import fails**: Verify file permissions and format
            • **Duplicates detected**: Review import preview carefully
            
            **External Display Issues:**
            • **No external display**: Check cable connections
            • **Display not mirroring**: Verify AirPlay or adapter setup
            • **Poor quality**: Adjust resolution settings
            
            **Performance Issues:**
            • **Slow scrolling**: Restart app if hymn list is very large
            • **Memory warnings**: Close other apps to free memory
            • **Crashes during import**: Import smaller file sets
            
            **Data Issues:**
            • **Missing hymns**: Check if correct service filter is active
            • **Search not working**: Clear search and try again
            • **Service hymns missing**: Verify service is active
            
            **Getting Help:**
            Contact support with specific error messages and steps to reproduce issues.
            """
        }
    }
    
    var relatedTopics: [HelpTopic] {
        switch self {
        case .overview:
            return [.addingFirstHymn, .navigatingInterface, .basicPresentation]
        case .addingFirstHymn:
            return [.creatingHymns, .editingHymns, .importingHymns]
        case .navigatingInterface:
            return [.searchingHymns, .multiSelect, .keyboardShortcuts]
        case .creatingHymns:
            return [.addingFirstHymn, .editingHymns, .importingHymns]
        case .editingHymns:
            return [.creatingHymns, .deletingHymns, .fontAdjustment]
        case .deletingHymns:
            return [.batchOperations, .multiSelect, .troubleshooting]
        case .searchingHymns:
            return [.navigatingInterface, .multiSelect, .batchOperations]
        case .importingHymns:
            return [.exportingHymns, .creatingHymns, .troubleshooting]
        case .exportingHymns:
            return [.importingHymns, .batchOperations, .multiSelect]
        case .creatingServices:
            return [.managingServices, .addingHymnsToService, .reorderingHymns]
        case .managingServices:
            return [.creatingServices, .addingHymnsToService, .completingServices]
        case .addingHymnsToService:
            return [.managingServices, .reorderingHymns, .searchingHymns]
        case .reorderingHymns:
            return [.addingHymnsToService, .managingServices, .basicPresentation]
        case .completingServices:
            return [.managingServices, .creatingServices, .exportingHymns]
        case .basicPresentation:
            return [.externalDisplay, .presentationControls, .fontAdjustment]
        case .externalDisplay:
            return [.basicPresentation, .presentationControls, .troubleshooting]
        case .presentationControls:
            return [.basicPresentation, .externalDisplay, .fontAdjustment]
        case .fontAdjustment:
            return [.basicPresentation, .editingHymns, .presentationControls]
        case .multiSelect:
            return [.batchOperations, .deletingHymns, .exportingHymns]
        case .batchOperations:
            return [.multiSelect, .deletingHymns, .exportingHymns]
        case .keyboardShortcuts:
            return [.navigatingInterface, .basicPresentation, .multiSelect]
        case .troubleshooting:
            return [.importingHymns, .externalDisplay, .deletingHymns]
        }
    }
}

// MARK: - Help Context

enum HelpContext {
    case emptyHymnList
    case hymnSelected
    case multiSelectMode
    case serviceManagement
    case importing
    case exporting
    case externalDisplay
}