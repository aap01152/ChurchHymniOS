# Today's Worship Service Feature - Implementation Plan

## Overview

This document outlines the comprehensive implementation plan for the "Today's Worship Service" feature, which enables church song leaders to create, manage, and organize hymn playlists for worship services. The feature provides intuitive hymn selection, reordering, filtering, and service management capabilities while integrating seamlessly with the existing external display presentation system.

## Feature Requirements

### Core Functionality
1. **Service Creation & Management**
   - Create new worship services with date and optional title/notes
   - Add hymns to services from the main hymn library
   - Remove hymns from services
   - Delete entire services when no longer needed

2. **Hymn Selection & Organization**
   - Quick "Add to Today's Service" action from hymn list
   - Drag-and-drop reordering within service
   - Visual indication of hymns already in service
   - Batch selection for adding multiple hymns

3. **Service Filtering & Navigation**
   - "Today's Service" filter in main hymn list
   - Dedicated service view showing only selected hymns
   - Quick toggle between library view and service view
   - Service hymn count and metadata display

4. **Service Workflow Support**
   - Clear visual order indication (1, 2, 3, etc.)
   - Easy service clearing at end of worship
   - Service archiving for future reference
   - Export service lists for sharing

## Data Architecture

### New Data Models

#### WorshipService Model
```swift
@Model
class WorshipService {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var isActive: Bool // Marks the current/today's service
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var serviceHymns: [ServiceHymn] = []
    
    init(title: String, date: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.isActive = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

#### ServiceHymn Model (Junction Table with Ordering)
```swift
@Model
class ServiceHymn {
    @Attribute(.unique) var id: UUID
    var hymnId: UUID // Reference to Hymn
    var serviceId: UUID // Reference to WorshipService
    var order: Int
    var addedAt: Date
    
    // Computed property to get hymn (requires context query)
    // var hymn: Hymn? { /* Query hymn by hymnId */ }
    
    init(hymnId: UUID, serviceId: UUID, order: Int) {
        self.id = UUID()
        self.hymnId = hymnId
        self.serviceId = serviceId
        self.order = order
        self.addedAt = Date()
    }
}
```

### Design Rationale
- **Separate ServiceHymn Entity**: Maintains hymn order without modifying core Hymn model
- **Reference by ID**: Avoids complex SwiftData relationships while maintaining data integrity
- **isActive Flag**: Simple way to mark "today's" service without complex date logic
- **Lightweight Design**: Minimal impact on existing hymn management system

## UI/UX Design

### Main Interface Integration

#### 1. Library View Enhancements
**Location**: `HymnListView.swift`

**New Elements**:
- **"Add to Service" Button**: Context menu or swipe action on hymn rows
- **Service Indicator**: Small icon showing hymns already in today's service
- **Service Filter Toggle**: "Show Today's Service" button in toolbar
- **Batch Add Mode**: Multi-select to add multiple hymns to service

#### 2. Service Management Interface
**New Component**: `ServiceView.swift`

**Features**:
- **Service Header**: Date, title, hymn count, service notes
- **Reorderable List**: Drag handles for hymn reordering
- **Service Controls**: Clear service, archive service, create new service
- **Quick Actions**: Remove hymns, add more hymns, start presentation

#### 3. Toolbar Integration
**Location**: `ContentView.swift` and `HymnToolbarView.swift`

**New Toolbar Items**:
- **Service Toggle**: Switch between library and service view
- **Service Count Badge**: Shows number of hymns in today's service
- **Service Actions Menu**: Quick access to service operations

### Navigation Flow

```
Main Library View
├── Filter: "Show All" (default)
├── Filter: "Today's Service"
└── Toolbar: Service Actions
    ├── View Today's Service → ServiceView
    ├── Create New Service → Service Creation Modal
    └── Manage Services → Service History View
```

### Visual Design Patterns

#### Service Indicators
- **In Service**: Blue accent dot next to hymn title
- **Service Order**: Small numbered badge (1, 2, 3...) when in service view
- **Quick Add**: Plus icon with haptic feedback
- **Drag Handle**: Three-line grip icon for reordering

#### Color Coding
- **Active Service**: Blue accent color (consistent with app theme)
- **Service Indicator**: Subtle blue dot or badge
- **Order Numbers**: White text on blue background
- **Remove Actions**: Red accent for destructive actions

## Implementation Phases

### Phase 1: Data Foundation (Week 1)
**Files to Create/Modify**: 
- `WorshipService.swift` - New data model
- `ServiceHymn.swift` - New junction model
- `ServiceOperations.swift` - Business logic class

**Key Tasks**:
- [ ] Implement SwiftData models with proper relationships
- [ ] Create service operations class following `HymnOperations` pattern
- [ ] Implement CRUD operations for services and service hymns
- [ ] Add data migration support for existing installations

**Data Operations**:
```swift
class ServiceOperations: ObservableObject {
    @Published var currentService: WorshipService?
    @Published var isLoading = false
    
    func createTodaysService() async
    func addHymnToService(hymn: Hymn, service: WorshipService)
    func removeHymnFromService(hymnId: UUID, service: WorshipService)
    func reorderServiceHymns(service: WorshipService, from: Int, to: Int)
    func clearService(service: WorshipService)
    func setActiveService(service: WorshipService)
}
```

### Phase 2: Core UI Integration (Week 2)
**Files to Modify**:
- `HymnListView.swift` - Add service indicators and actions
- `ContentView.swift` - Integrate service state management
- `HymnToolbarView.swift` - Add service toolbar items

**Key Tasks**:
- [ ] Add service indicators to hymn list items
- [ ] Implement "Add to Service" actions (tap, context menu, swipe)
- [ ] Create service filter toggle in hymn list
- [ ] Add service count badge to toolbar
- [ ] Implement visual feedback for service membership

**UI Enhancements**:
```swift
// HymnListView addition
var serviceIndicator: some View {
    if isInTodaysService(hymn) {
        Image(systemName: "music.note")
            .foregroundColor(.accentColor)
            .font(.caption)
    }
}

// Context menu addition
.contextMenu {
    if isInTodaysService(hymn) {
        Button("Remove from Service") { removeFromService(hymn) }
    } else {
        Button("Add to Service") { addToService(hymn) }
    }
}
```

### Phase 3: Service View & Management (Week 3)
**Files to Create**:
- `ServiceView.swift` - Dedicated service management interface
- `ServiceCreationView.swift` - Modal for creating new services
- `ServiceHistoryView.swift` - View past services

**Key Tasks**:
- [ ] Build reorderable service hymn list with drag-and-drop
- [ ] Implement service header with metadata and controls
- [ ] Create service creation and editing modals
- [ ] Add service clearing and archiving functionality
- [ ] Implement service history and management interface

**Service View Features**:
```swift
struct ServiceView: View {
    @StateObject var serviceOperations: ServiceOperations
    @State private var draggedHymn: ServiceHymn?
    
    var body: some View {
        NavigationView {
            VStack {
                serviceHeader
                reorderableHymnList
                serviceActions
            }
        }
    }
}
```

### Phase 4: Advanced Features (Week 4)
**Files to Modify**:
- `ExternalDisplayManager.swift` - Integrate service playback
- `ServiceOperations.swift` - Add export and sharing
- Localization files - Add service-related strings

**Key Tasks**:
- [ ] Integrate service hymns with external display presentation
- [ ] Add service export functionality (text, PDF, print)
- [ ] Implement service templates and presets
- [ ] Add advanced service scheduling and reminders
- [ ] Create service analytics and usage tracking

**External Display Integration**:
```swift
extension ExternalDisplayManager {
    func presentServiceHymns(service: WorshipService) {
        // Set up service presentation mode
        // Show service progress indicator
        // Navigate through service hymns in order
    }
}
```

## Technical Implementation Details

### State Management Strategy

#### Primary State Objects
```swift
// In ContentView
@StateObject private var serviceOperations = ServiceOperations()
@Query private var services: [WorshipService]
@Query private var currentServiceHymns: [ServiceHymn]

// Computed Properties
var todaysService: WorshipService? {
    services.first { $0.isActive }
}

var serviceHymns: [Hymn] {
    // Query hymns that match service hymn IDs, ordered by service order
}
```

#### Filter Integration
```swift
// Enhanced filtering in HymnListView
enum HymnFilter: CaseIterable {
    case all
    case todaysService
    case recentlyAdded
    case favorites // Future enhancement
}

var filteredHymns: [Hymn] {
    switch selectedFilter {
    case .all: return hymns.filter(searchPredicate)
    case .todaysService: return serviceHymns.filter(searchPredicate)
    // ... other filters
    }
}
```

### Performance Considerations

#### Data Optimization
- **Lazy Loading**: Load service hymns only when needed
- **Efficient Queries**: Use SwiftData predicates for filtering
- **Memory Management**: Proper cleanup of service state
- **Background Updates**: Async operations for service modifications

#### UI Performance
- **List Virtualization**: Efficient rendering of large hymn lists
- **Smooth Animations**: Optimized drag-and-drop with haptic feedback
- **State Synchronization**: Minimal re-renders on service changes
- **Image Caching**: Efficient icon and indicator rendering

### Error Handling & Edge Cases

#### Data Integrity
- **Orphaned Service Hymns**: Cleanup when hymns are deleted
- **Service Consistency**: Ensure proper order numbering
- **Concurrent Modifications**: Handle simultaneous service edits
- **Data Migration**: Graceful upgrades from non-service versions

#### User Experience
- **Network Issues**: Offline service management
- **Large Services**: Performance with 100+ hymns
- **Interrupted Operations**: Recovery from incomplete actions
- **Accessibility**: Full VoiceOver and keyboard navigation support

### Accessibility Implementation

#### VoiceOver Support
```swift
.accessibilityLabel("Hymn \(hymn.title)")
.accessibilityHint(isInService ? "In today's service at position \(servicePosition)" : "Tap to add to service")
.accessibilityAddTraits(isInService ? .isSelected : [])
```

#### Keyboard Navigation
- **Tab Order**: Logical navigation through service interface
- **Shortcuts**: Quick keys for common service actions
- **Focus Management**: Proper focus handling in modals and lists
- **Screen Reader**: Clear announcements for service changes

### Localization Strategy

#### New Localization Keys
```swift
// Service Management
"service.todays_service" = "Today's Service"
"service.create_new" = "Create New Service"
"service.add_hymn" = "Add to Service"
"service.remove_hymn" = "Remove from Service"
"service.clear_service" = "Clear Service"
"service.hymn_count" = "%d hymns in service"

// Service Actions
"service.reorder_hymn" = "Reorder hymn"
"service.position_number" = "Position %d"
"service.start_presentation" = "Start Service Presentation"

// Accessibility
"service.accessibility.add_to_service" = "Add hymn to today's service"
"service.accessibility.remove_from_service" = "Remove hymn from service"
"service.accessibility.reorder_handle" = "Drag to reorder hymn position"
```

## Testing Strategy

### Unit Tests
- [ ] Service data model CRUD operations
- [ ] Service hymn ordering logic
- [ ] Filter and search functionality with services
- [ ] Service operations error handling

### Integration Tests
- [ ] Service creation and management workflows
- [ ] Hymn addition and removal from services
- [ ] External display integration with services
- [ ] Data persistence across app launches

### User Testing Scenarios
1. **Service Creation**: Create service, add hymns, reorder, present
2. **Worship Flow**: Use service during actual worship service
3. **Multiple Services**: Manage multiple services (past, future, archive)
4. **External Display**: Present service hymns on external display
5. **Data Management**: Import/export with service data

## Future Enhancement Opportunities

### Advanced Service Features
- **Service Templates**: Reusable service patterns
- **Recurring Services**: Weekly/monthly service automation
- **Service Sharing**: Share services between devices/users
- **Service Analytics**: Track hymn usage and preferences

### Integration Possibilities
- **Calendar Integration**: Schedule services in device calendar
- **Church Management Systems**: Export to popular church software
- **Music Theory**: Suggest hymn keys and transitions
- **Lyrics Display**: Enhanced external display with service context

### Collaboration Features
- **Team Services**: Multi-user service planning
- **Service Comments**: Notes and feedback on hymn choices
- **Version Control**: Track service changes over time
- **Remote Control**: Control presentation from any device

## Implementation Timeline

### Sprint 1 (Week 1): Data Foundation
- **Day 1-2**: Create data models and database schema
- **Day 3-4**: Implement service operations and business logic
- **Day 5-7**: Unit tests and data validation

### Sprint 2 (Week 2): Basic UI Integration
- **Day 1-3**: Modify hymn list with service indicators
- **Day 4-5**: Add toolbar service controls
- **Day 6-7**: Implement basic add/remove functionality

### Sprint 3 (Week 3): Service Management Interface
- **Day 1-3**: Build dedicated service view
- **Day 4-5**: Implement drag-and-drop reordering
- **Day 6-7**: Add service creation and management

### Sprint 4 (Week 4): Polish & Advanced Features
- **Day 1-2**: External display integration
- **Day 3-4**: Export and sharing capabilities
- **Day 5-7**: Testing, polish, and documentation

## Success Metrics

### Functional Requirements
- ✅ Create and manage worship services
- ✅ Add/remove hymns from services with visual feedback
- ✅ Reorder service hymns via drag-and-drop
- ✅ Filter hymn list to show only service hymns
- ✅ Clear service at end of worship
- ✅ External display integration for service presentation

### Performance Requirements
- 📊 Service creation in < 2 seconds
- 📊 Hymn addition/removal with < 500ms feedback
- 📊 Smooth drag-and-drop with 60fps animations
- 📊 Filter switching in < 1 second
- 📊 Support services with 100+ hymns without performance degradation

### User Experience Requirements
- 🎯 Intuitive service creation workflow
- 🎯 Clear visual indication of service membership
- 🎯 Seamless integration with existing hymn management
- 🎯 Accessible interface with full VoiceOver support
- 🎯 Consistent with existing app design patterns

This comprehensive implementation plan provides a solid foundation for building the "Today's Worship Service" feature while maintaining the high quality and user experience standards of the existing application.