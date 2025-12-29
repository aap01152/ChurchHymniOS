//
//  KeyboardShortcuts.swift
//  ChurchHymn
//
//  Created by Claude on 29/12/2025.
//

import SwiftUI

/// Centralized keyboard shortcuts for ChurchHymn app
/// Provides consistent keyboard shortcuts across the application
struct KeyboardShortcuts {
    
    // MARK: - Seamless Hymn Switching Shortcuts
    
    /// Present currently viewed hymn (⌘ + Shift + P)
    static let presentCurrentHymn = KeyboardShortcut("p", modifiers: [.command, .shift])
    
    // MARK: - Navigation Shortcuts
    
    /// Focus search field (⌘ + F)
    static let focusSearch = KeyboardShortcut("f", modifiers: .command)
    
    /// Add new hymn (⌘ + N)
    static let addNewHymn = KeyboardShortcut("n", modifiers: .command)
    
    /// Edit selected hymn (⌘ + E)
    static let editHymn = KeyboardShortcut("e", modifiers: .command)
    
    /// Delete selected hymn (⌘ + D)
    static let deleteHymn = KeyboardShortcut("d", modifiers: .command)
    
    /// Present selected hymn (⌘ + P)
    static let presentHymn = KeyboardShortcut("p", modifiers: .command)
    
    // MARK: - File Operations
    
    /// Import hymns (⌘ + I)
    static let importHymns = KeyboardShortcut("i", modifiers: .command)
    
    /// Export selected hymn (⌘ + S)
    static let exportHymn = KeyboardShortcut("s", modifiers: .command)
    
    /// Select all (⌘ + A)
    static let selectAll = KeyboardShortcut("a", modifiers: .command)
    
    // MARK: - Presentation Shortcuts
    
    /// Start/stop presentation (Space)
    static let togglePresentation = KeyboardShortcut(.space, modifiers: [])
    
    /// Navigate to previous verse (Left Arrow)
    static let previousVerse = KeyboardShortcut(.leftArrow, modifiers: [])
    
    /// Navigate to next verse (Right Arrow)
    static let nextVerse = KeyboardShortcut(.rightArrow, modifiers: [])
    
    /// Increase font size (⌘ + Plus)
    static let increaseFontSize = KeyboardShortcut("+", modifiers: .command)
    
    /// Decrease font size (⌘ + Minus)
    static let decreaseFontSize = KeyboardShortcut("-", modifiers: .command)
    
    /// Exit presentation mode (Escape)
    static let exitPresentation = KeyboardShortcut(.escape, modifiers: [])
    
    // MARK: - Service Management
    
    /// Open service management (⌘ + R)
    static let openServices = KeyboardShortcut("r", modifiers: .command)
    
    /// Create new service (⌘ + T)
    static let createService = KeyboardShortcut("t", modifiers: .command)
    
    // MARK: - Worship Session Shortcuts
    
    /// Start worship session (⌘ + Shift + W)
    static let startWorshipSession = KeyboardShortcut("w", modifiers: [.command, .shift])
    
    /// Stop worship session (⌘ + Shift + S)
    static let stopWorshipSession = KeyboardShortcut("s", modifiers: [.command, .shift])
    
    /// Toggle external display (⌘ + Shift + E)
    static let toggleExternalDisplay = KeyboardShortcut("e", modifiers: [.command, .shift])
}

/// View modifier for adding keyboard shortcuts to the ContentView
struct ContentKeyboardShortcuts: ViewModifier {
    let hymnService: HymnService?
    let selectedHymn: Hymn?
    let worshipSessionManager: WorshipSessionManager
    let externalDisplayManager: ExternalDisplayManager
    
    let onAddHymn: () -> Void
    let onEditHymn: () -> Void
    let onDeleteHymn: () -> Void
    let onPresentHymn: () -> Void
    let onPresentCurrentHymn: () -> Void
    let onImportHymns: () -> Void
    let onExportHymn: () -> Void
    let onToggleMultiSelect: () -> Void
    let onStartWorshipSession: () -> Void
    let onStopWorshipSession: () -> Void
    
    func body(content: Content) -> some View {
        content
            .modifier(BasicKeyboardShortcuts(
                onAddHymn: onAddHymn,
                onEditHymn: onEditHymn,
                onDeleteHymn: onDeleteHymn,
                onImportHymns: onImportHymns,
                onToggleMultiSelect: onToggleMultiSelect,
                selectedHymn: selectedHymn
            ))
            .modifier(PresentationKeyboardShortcuts(
                onPresentHymn: onPresentHymn,
                onPresentCurrentHymn: onPresentCurrentHymn,
                onExportHymn: onExportHymn,
                selectedHymn: selectedHymn,
                worshipSessionManager: worshipSessionManager
            ))
            .modifier(WorkshipKeyboardShortcuts(
                onStartWorshipSession: onStartWorshipSession,
                onStopWorshipSession: onStopWorshipSession,
                worshipSessionManager: worshipSessionManager
            ))
    }
}

/// Basic keyboard shortcuts for file operations and navigation
struct BasicKeyboardShortcuts: ViewModifier {
    let onAddHymn: () -> Void
    let onEditHymn: () -> Void
    let onDeleteHymn: () -> Void
    let onImportHymns: () -> Void
    let onToggleMultiSelect: () -> Void
    let selectedHymn: Hymn?
    
    func body(content: Content) -> some View {
        content
            .background(
                VStack {
                    // Add Hymn shortcut
                    Button("") { onAddHymn() }
                        .keyboardShortcut("n", modifiers: .command)
                        .hidden()
                    
                    // Edit Hymn shortcut
                    if selectedHymn != nil {
                        Button("") { onEditHymn() }
                            .keyboardShortcut("e", modifiers: .command)
                            .hidden()
                    }
                    
                    // Delete Hymn shortcut
                    if selectedHymn != nil {
                        Button("") { onDeleteHymn() }
                            .keyboardShortcut("d", modifiers: .command)
                            .hidden()
                    }
                    
                    // Import Hymns shortcut
                    Button("") { onImportHymns() }
                        .keyboardShortcut("i", modifiers: .command)
                        .hidden()
                    
                    // Select All shortcut
                    Button("") { onToggleMultiSelect() }
                        .keyboardShortcut("a", modifiers: .command)
                        .hidden()
                }
            )
    }
}

/// Presentation-related keyboard shortcuts
struct PresentationKeyboardShortcuts: ViewModifier {
    let onPresentHymn: () -> Void
    let onPresentCurrentHymn: () -> Void
    let onExportHymn: () -> Void
    let selectedHymn: Hymn?
    let worshipSessionManager: WorshipSessionManager
    
    func body(content: Content) -> some View {
        content
            .background(
                VStack {
                    // Present Hymn shortcut
                    if selectedHymn != nil {
                        Button("") { onPresentHymn() }
                            .keyboardShortcut("p", modifiers: .command)
                            .hidden()
                    }
                    
                    // Present Current Hymn (seamless switch) shortcut
                    if worshipSessionManager.isWorshipSessionActive,
                       let hymn = selectedHymn,
                       worshipSessionManager.canPresentHymn(hymn) {
                        Button("") { onPresentCurrentHymn() }
                            .keyboardShortcut("p", modifiers: [.command, .shift])
                            .hidden()
                    }
                    
                    // Export Hymn shortcut
                    if selectedHymn != nil {
                        Button("") { onExportHymn() }
                            .keyboardShortcut("s", modifiers: .command)
                            .hidden()
                    }
                }
            )
    }
}

/// Worship session keyboard shortcuts
struct WorkshipKeyboardShortcuts: ViewModifier {
    let onStartWorshipSession: () -> Void
    let onStopWorshipSession: () -> Void
    let worshipSessionManager: WorshipSessionManager
    
    func body(content: Content) -> some View {
        content
            .background(
                VStack {
                    // Start Worship Session shortcut
                    if worshipSessionManager.canStartWorshipSession {
                        Button("") { onStartWorshipSession() }
                            .keyboardShortcut("w", modifiers: [.command, .shift])
                            .hidden()
                    }
                    
                    // Stop Worship Session shortcut
                    if worshipSessionManager.canStopWorshipSession {
                        Button("") { onStopWorshipSession() }
                            .keyboardShortcut("s", modifiers: [.command, .shift])
                            .hidden()
                    }
                }
            )
    }
}

/// Extension for easy application of keyboard shortcuts
extension View {
    func contentKeyboardShortcuts(
        hymnService: HymnService?,
        selectedHymn: Hymn?,
        worshipSessionManager: WorshipSessionManager,
        externalDisplayManager: ExternalDisplayManager,
        onAddHymn: @escaping () -> Void,
        onEditHymn: @escaping () -> Void,
        onDeleteHymn: @escaping () -> Void,
        onPresentHymn: @escaping () -> Void,
        onPresentCurrentHymn: @escaping () -> Void,
        onImportHymns: @escaping () -> Void,
        onExportHymn: @escaping () -> Void,
        onToggleMultiSelect: @escaping () -> Void,
        onStartWorshipSession: @escaping () -> Void,
        onStopWorshipSession: @escaping () -> Void
    ) -> some View {
        self.modifier(ContentKeyboardShortcuts(
            hymnService: hymnService,
            selectedHymn: selectedHymn,
            worshipSessionManager: worshipSessionManager,
            externalDisplayManager: externalDisplayManager,
            onAddHymn: onAddHymn,
            onEditHymn: onEditHymn,
            onDeleteHymn: onDeleteHymn,
            onPresentHymn: onPresentHymn,
            onPresentCurrentHymn: onPresentCurrentHymn,
            onImportHymns: onImportHymns,
            onExportHymn: onExportHymn,
            onToggleMultiSelect: onToggleMultiSelect,
            onStartWorshipSession: onStartWorshipSession,
            onStopWorshipSession: onStopWorshipSession
        ))
    }
}