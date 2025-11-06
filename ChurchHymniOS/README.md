# 🎵 Church Hymn App

A powerful macOS application for managing and presenting church hymns with advanced import/export capabilities, streaming support, and background processing.

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [User Guide](#-user-guide)
- [Developer Guide](#-developer-guide)
- [File Formats](#-file-formats)
- [Architecture](#-architecture)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## ✨ Features

### 🎯 Core Features
- **Hymn Management**: Create, edit, and organize church hymns
- **Presentation Mode**: Full-screen presentation with customizable display
- **Import/Export**: Support for JSON and plain text formats
- **Batch Operations**: Multi-select and batch operations for efficiency
- **Search & Filter**: Find hymns quickly with search functionality

### 🚀 Advanced Features
- **Streaming Support**: Handle large hymn collections efficiently
- **Background Processing**: Import/export operations run in background
- **Duplicate Detection**: Smart duplicate handling with merge options
- **Progress Tracking**: Real-time progress for long operations
- **Memory Optimization**: Efficient memory usage for large collections

### 🎨 User Interface
- **Native macOS Design**: Consistent with macOS design patterns
- **Responsive Layout**: Adapts to different window sizes
- **Keyboard Shortcuts**: Power user shortcuts for efficiency
- **Context Menus**: Right-click actions for quick access
- **Toolbar Integration**: Quick access to common actions

## 📦 Installation

### For Users

1. **Download the App**
   - Download the latest release from the releases page
   - Or build from source (see Developer Guide)

2. **Install on macOS**
   - Drag the app to your Applications folder
   - First launch may require security approval in System Preferences

3. **Grant Permissions**
   - Allow file access when prompted
   - Enable background processing if needed

### For Developers

1. **Prerequisites**
   ```bash
   # macOS 14.0+ (Sonoma)
   # Xcode 15.0+
   # Swift 5.9+
   ```

2. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/ChurchHymn.git
   cd ChurchHymn
   ```

3. **Open in Xcode**
   ```bash
   open ChurchHymn.xcodeproj
   ```

4. **Build and Run**
   - Select your target device (Mac)
   - Press `Cmd+R` to build and run

## 👥 User Guide

### Getting Started

1. **Launch the App**
   - Open Church Hymn from Applications
   - The main window shows your hymn library

2. **Add Your First Hymn**
   - Click the "Add" button in the toolbar
   - Fill in the hymn details (title is required)
   - Click "Save" to add the hymn

3. **Import Existing Hymns**
   - Click "Import JSON" or "Import Plain Text"
   - Select your hymn file
   - Review and confirm the import

### Managing Hymns

#### Creating Hymns
1. **Click "Add"** in the toolbar
2. **Fill in the details**:
   - **Title** (required): The hymn title
   - **Lyrics**: The full hymn text
   - **Musical Key**: The musical key (e.g., C, G, F#)
   - **Author**: The hymn author
   - **Copyright**: Copyright information
   - **Tags**: Keywords for organization
   - **Notes**: Additional notes
3. **Click "Save"**

#### Editing Hymns
1. **Select a hymn** from the list
2. **Right-click** and select "Edit"
3. **Make your changes**
4. **Click "Save"**

#### Deleting Hymns
1. **Select a hymn** from the list
2. **Right-click** and select "Delete"
3. **Confirm deletion** in the dialog

### Batch Operations

#### Multi-Select Mode
1. **Click "Multi-Select"** in the toolbar
2. **Select multiple hymns** using checkboxes
3. **Perform batch operations**:
   - Delete selected hymns
   - Export selected hymns
   - Process multiple hymns at once

#### Batch Delete
1. **Enter Multi-Select mode**
2. **Select hymns** to delete
3. **Click "Delete Selected"**
4. **Confirm** the batch deletion

### Import/Export

#### Importing Hymns

**JSON Format**
- Supports single hymn or batch import
- Maintains all hymn metadata
- Automatic duplicate detection

**Plain Text Format**
- Simple text-based format
- First non-empty line is the title
- Metadata lines start with `#`
- Lyrics blocks separated by empty lines

#### Exporting Hymns

**Single Hymn Export**
1. **Select a hymn** from the list
2. **Click "Export Selected"**
3. **Choose format** (JSON or Plain Text)
4. **Select destination** and save

**Batch Export**
1. **Click "Export Multiple"** or "Export All"
2. **Select hymns** to export
3. **Choose format** and destination
4. **Confirm export**

#### Large Collections

For large hymn collections (>1000 hymns):
- **Automatic streaming** for memory efficiency
- **Background processing** to avoid blocking the UI
- **Progress tracking** with detailed information
- **Memory optimization** for smooth operation

### Presentation Mode

#### Starting Presentation
1. **Select a hymn** from the list
2. **Click "Present"** or right-click and select "Present"
3. **A new window opens** with the hymn display

#### Presentation Controls
- **Full-screen mode** available
- **Font size adjustment** for visibility
- **Background color** customization
- **Keyboard shortcuts** for navigation

#### Presentation Features
- **Large, readable text** for congregation viewing
- **Scrollable lyrics** for long hymns
- **Professional appearance** suitable for church use
- **Easy navigation** between verses

### Advanced Features

#### Background Processing
- **Background Import**: Schedule large imports to run in background
- **Background Export**: Export large collections without blocking UI
- **Task Management**: View and manage background tasks
- **Progress Tracking**: Monitor background task progress

#### Streaming Operations
- **Large File Support**: Handle files >10MB efficiently
- **Memory Management**: Optimized memory usage
- **Progress Reporting**: Real-time progress updates
- **Error Recovery**: Robust error handling

## 👨‍💻 Developer Guide

### Project Structure

```
ChurchHymn/
├── ChurchHymnApp.swift          # App entry point
├── ContentView.swift            # Main view controller
├── Hymn.swift                   # Data model
├── HymnEditView.swift           # Hymn editing interface
├── PresenterView.swift          # Presentation mode
├── HymnListView.swift           # Hymn list component
├── HymnToolbar.swift            # Toolbar component
├── HymnOperations.swift         # Core operations
├── HymnStreamingOperations.swift # Streaming operations
├── HymnTypes.swift              # Type definitions
├── ProgressOverlay.swift        # Progress UI
├── StreamingProgressOverlay.swift # Streaming progress
├── ImportPreviewView.swift      # Import preview
├── ExportSelectionView.swift    # Export selection
├── LyricsDetailView.swift       # Lyrics display
└── IMPORT_EXPORT_FORMATS.md     # Format documentation
```

### Architecture Overview

#### Data Layer
- **SwiftData**: Modern data persistence framework
- **Hymn Model**: Core data model with Codable support
- **Import/Export**: JSON and plain text format support

#### Business Logic
- **HymnOperations**: Core import/export operations
- **StreamingOperations**: Large file handling
- **Background Tasks**: Background processing support

#### UI Layer
- **SwiftUI**: Modern declarative UI framework
- **Component Architecture**: Modular, reusable components
- **Progress Tracking**: Real-time operation feedback

### Key Components

#### Hymn Model
```swift
@Model
class Hymn {
    var id: UUID
    var title: String
    var lyrics: String?
    var musicalKey: String?
    var copyright: String?
    var author: String?
    var tags: [String]?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}
```

#### Operations System
- **HymnOperations**: Standard import/export operations
- **StreamingOperations**: Memory-efficient large file handling
- **Background Tasks**: Non-blocking background processing

### Development Setup

#### Environment Requirements
```bash
# macOS 14.0+ (Sonoma)
# Xcode 15.0+
# Swift 5.9+
# SwiftData support
```

#### Build Configuration
1. **Open project** in Xcode
2. **Select target** (ChurchHymn)
3. **Configure signing** (automatic or manual)
4. **Set deployment target** (macOS 14.0+)
5. **Enable capabilities**:
   - Background Modes
   - File Access

#### Code Style
- **SwiftUI**: Modern declarative syntax
- **Swift Concurrency**: Async/await for operations
- **Error Handling**: Comprehensive error management
- **Documentation**: Inline documentation for public APIs

### Adding New Features

#### 1. Data Model Changes
```swift
// Add new properties to Hymn model
@Model
class Hymn {
    // ... existing properties
    var newProperty: String?
}
```

#### 2. UI Components
```swift
// Create new SwiftUI view
struct NewFeatureView: View {
    var body: some View {
        // Your UI implementation
    }
}
```

#### 3. Operations
```swift
// Add to HymnOperations class
func newOperation() async throws {
    // Implementation
}
```

### Testing

#### Unit Tests
```bash
# Run unit tests
xcodebuild test -scheme ChurchHymn -destination 'platform=macOS'
```

#### UI Tests
```bash
# Run UI tests
xcodebuild test -scheme ChurchHymn -destination 'platform=macOS' -only-testing:ChurchHymnUITests
```

## 📄 File Formats

### JSON Format

#### Single Hymn
```json
{
  "title": "Amazing Grace",
  "lyrics": "Amazing grace, how sweet the sound...",
  "musicalKey": "C",
  "author": "John Newton",
  "copyright": "Public Domain",
  "tags": ["grace", "salvation"],
  "notes": "Traditional hymn"
}
```

#### Batch Import
```json
[
  {
    "title": "Hymn 1",
    "lyrics": "..."
  },
  {
    "title": "Hymn 2", 
    "lyrics": "..."
  }
]
```

### Plain Text Format

```
# Amazing Grace
# Key: C
# Author: John Newton
# Copyright: Public Domain
# Tags: grace, salvation

Amazing grace, how sweet the sound
That saved a wretch like me
I once was lost, but now I'm found
Was blind, but now I see

Through many dangers, toils, and snares
I have already come
'Tis grace hath brought me safe thus far
And grace will lead me home
```

## 🏗️ Architecture

### Design Patterns

#### MVVM (Model-View-ViewModel)
- **Model**: Hymn data model with SwiftData
- **View**: SwiftUI views for UI components
- **ViewModel**: ObservableObject classes for business logic

#### Repository Pattern
- **Data Access**: Centralized data operations
- **Abstraction**: Clean separation of concerns
- **Testability**: Easy to mock and test

#### Observer Pattern
- **@Published**: Reactive UI updates
- **@StateObject**: Managed object lifecycle
- **@EnvironmentObject**: Dependency injection

### Data Flow

1. **User Action** → UI Component
2. **UI Component** → ViewModel/Operations
3. **Operations** → Data Layer
4. **Data Layer** → SwiftData
5. **Updates** → UI via @Published properties

### Error Handling

#### Error Types
```swift
enum ImportError: LocalizedError, Identifiable {
    case fileReadFailed(String)
    case invalidFormat(String)
    case missingTitle
    case emptyFile
    case permissionDenied
    case fileNotFound
    case corruptedData(String)
    case unknown(String)
}
```

#### Error Recovery
- **User Feedback**: Clear error messages
- **Recovery Suggestions**: Actionable solutions
- **Graceful Degradation**: App continues to function
- **Logging**: Comprehensive error logging

## 🔧 Troubleshooting

### Common Issues

#### Import/Export Problems

**"File not found" Error**
- Check file permissions
- Ensure file exists at specified path
- Try copying file to Downloads folder

**"Invalid format" Error**
- Verify file format (JSON or plain text)
- Check JSON syntax for JSON files
- Ensure plain text files have proper structure

**"Permission denied" Error**
- Grant file access permissions
- Check macOS security settings
- Try running with elevated permissions

#### Performance Issues

**Slow Import/Export**
- Use streaming for large files (>10MB)
- Enable background processing
- Check available memory
- Close other applications

**Memory Usage**
- App automatically uses streaming for large collections
- Background tasks reduce memory pressure
- Restart app if memory issues persist

#### UI Issues

**Window Not Responding**
- Check for background operations
- Wait for operation completion
- Force quit and restart if necessary

**Display Problems**
- Check macOS display settings
- Update graphics drivers
- Restart the application

### Debug Information

#### Logs
```bash
# View system logs
log show --predicate 'subsystem == "com.churchhymn"' --last 1h
```

#### Console Output
- Check Xcode console for debug information
- Look for error messages and warnings
- Verify operation completion

#### Performance Monitoring
- Monitor memory usage in Activity Monitor
- Check CPU usage during operations
- Verify disk I/O for file operations

## 🤝 Contributing

### Getting Started

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests** for new functionality
5. **Submit a pull request**

### Development Guidelines

#### Code Style
- Follow Swift style guidelines
- Use meaningful variable names
- Add inline documentation
- Write unit tests for new features

#### Commit Messages
```
feat: add new import format support
fix: resolve memory leak in streaming operations
docs: update README with new features
test: add unit tests for background tasks
```

#### Pull Request Process
1. **Describe the changes** clearly
2. **Include screenshots** for UI changes
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Ensure all tests pass**

### Testing

#### Running Tests
```bash
# Unit tests
xcodebuild test -scheme ChurchHymn

# UI tests  
xcodebuild test -scheme ChurchHymn -only-testing:ChurchHymnUITests
```

#### Test Coverage
- Aim for >80% test coverage
- Test all public APIs
- Include edge cases
- Test error conditions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **SwiftUI** for the modern UI framework
- **SwiftData** for data persistence
- **macOS** for the excellent platform
- **Open Source Community** for inspiration and tools

## 📞 Support

### Getting Help

- **Documentation**: Check this README and inline docs
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Email**: Contact the maintainers directly

### Reporting Bugs

When reporting bugs, please include:
- **macOS version**
- **App version**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Screenshots** if applicable
- **Console logs** if available

---

**Happy Hymn Management! 🎵** 