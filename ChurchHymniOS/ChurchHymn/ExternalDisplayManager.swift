//
//  ExternalDisplayManager.swift
//  ChurchHymn
//
//  Created by paulo on 08/11/2025.
//

import SwiftUI
import UIKit
import Combine

@MainActor
class ExternalDisplayManager: ObservableObject {
    @Published var state: ExternalDisplayState = .disconnected
    @Published var externalDisplayInfo: ExternalDisplayInfo?
    @Published var currentHymn: Hymn?
    @Published var currentVerseIndex: Int = 0
    @Published var isPresenting: Bool = false
    
    private var externalWindow: UIWindow?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Worship Session Properties
    
    /// Whether currently in worship session mode
    var isInWorshipMode: Bool {
        return state.isWorshipSession
    }
    
    /// Whether can start worship session
    var canStartWorshipMode: Bool {
        return state.canStartWorshipSession
    }
    
    init() {
        setupSceneNotifications()
        checkForExternalDisplays()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// Public method to refresh external display state when app becomes active
    func refreshExternalDisplayState() {
        print("Refreshing external display state...")
        checkForExternalDisplays()
    }
    
    private func setupSceneNotifications() {
        // Use modern scene-based notifications instead of deprecated UIScreen notifications
        NotificationCenter.default.publisher(for: UIScene.willConnectNotification)
            .compactMap { $0.object as? UIWindowScene }
            .sink { [weak self] scene in
                self?.handleSceneWillConnect(scene)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)
            .compactMap { $0.object as? UIWindowScene }
            .sink { [weak self] scene in
                self?.handleSceneDidDisconnect(scene)
            }
            .store(in: &cancellables)
    }
    
    private func checkForExternalDisplays() {
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { isExternalDisplay($0) }
        
        if let externalScene = externalScenes.first {
            handleExternalDisplayConnected(externalScene)
        } else {
            handleExternalDisplayDisconnected()
        }
    }
    
    private func isExternalDisplay(_ scene: UIWindowScene) -> Bool {
        return scene.screen != UIScreen.main
    }
    
    private func handleSceneWillConnect(_ scene: UIWindowScene) {
        if isExternalDisplay(scene) {
            handleExternalDisplayConnected(scene)
        }
    }
    
    private func handleSceneDidDisconnect(_ scene: UIWindowScene) {
        if isExternalDisplay(scene) {
            handleExternalDisplayDisconnected()
        }
    }
    
    private func handleExternalDisplayConnected(_ scene: UIWindowScene) {
        let screen = scene.screen
        
        // Store the external screen info
        externalDisplayInfo = ExternalDisplayInfo(
            scene: scene,
            bounds: screen.bounds,
            scale: screen.scale,
            maximumFramesPerSecond: screen.maximumFramesPerSecond
        )
        
        state = .connected
    }
    
    private func handleExternalDisplayDisconnected() {
        if isPresenting {
            stopPresentation()
        }
        
        externalWindow = nil
        externalDisplayInfo = nil
        state = .disconnected
    }
    
    func startPresentation(hymn: Hymn, startingAtVerse: Int = 0) throws {
        guard state == .connected, let displayInfo = externalDisplayInfo else {
            throw ExternalDisplayError.noExternalDisplayFound
        }
        
        let scene = displayInfo.scene
        
        do {
            try createExternalWindow(for: scene)
            currentHymn = hymn
            currentVerseIndex = startingAtVerse
            isPresenting = true
            state = .presenting
            
            Task {
                await updateExternalDisplay()
            }
        } catch {
            throw ExternalDisplayError.presentationFailed(error.localizedDescription)
        }
    }
    
    func stopPresentation() {
        externalWindow?.isHidden = true
        externalWindow = nil
        currentHymn = nil
        currentVerseIndex = 0
        isPresenting = false
        
        // Check if external display is still connected
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { isExternalDisplay($0) }
        
        if !externalScenes.isEmpty {
            state = .connected
        } else {
            state = .disconnected
        }
    }
    
    // MARK: - Worship Session Methods
    
    /// Start worship mode - shows background image on external display
    func startWorshipMode() async throws {
        guard state == .connected, let displayInfo = externalDisplayInfo else {
            throw ExternalDisplayError.noExternalDisplayFound
        }
        
        do {
            try createExternalWindow(for: displayInfo.scene)
            state = .worshipMode
            await showWorshipBackground()
            print("Worship mode started")
        } catch {
            throw ExternalDisplayError.presentationFailed("Failed to start worship mode: \(error.localizedDescription)")
        }
    }
    
    /// Stop worship mode - return to connected state
    func stopWorshipMode() async {
        externalWindow?.isHidden = true
        externalWindow = nil
        currentHymn = nil
        currentVerseIndex = 0
        isPresenting = false
        
        // Return to connected state if display is still connected
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { isExternalDisplay($0) }
        
        if !externalScenes.isEmpty {
            state = .connected
        } else {
            state = .disconnected
        }
        
        print("Worship mode stopped")
    }
    
    /// Present hymn within worship session
    func presentHymnInWorshipMode(_ hymn: Hymn, startingAtVerse: Int = 0) async throws {
        guard state == .worshipMode, let displayInfo = externalDisplayInfo else {
            throw ExternalDisplayError.noExternalDisplayFound
        }
        
        do {
            currentHymn = hymn
            currentVerseIndex = startingAtVerse
            isPresenting = true
            state = .worshipPresenting
            
            await updateExternalDisplay()
            print("Hymn '\(hymn.title)' presented in worship mode")
        } catch {
            throw ExternalDisplayError.presentationFailed("Failed to present hymn in worship mode: \(error.localizedDescription)")
        }
    }
    
    /// Stop hymn presentation within worship session - return to background
    func stopHymnInWorshipMode() async {
        guard state == .worshipPresenting else { return }
        
        currentHymn = nil
        currentVerseIndex = 0
        isPresenting = false
        state = .worshipMode
        
        // Return to worship background
        await showWorshipBackground()
        print("Hymn presentation stopped - returned to worship background")
    }
    
    /// Show worship background image on external display
    private func showWorshipBackground() async {
        guard let window = externalWindow, state == .worshipMode else { 
            print("Cannot show worship background: window=\(externalWindow != nil), state=\(state)")
            return 
        }
        
        print("Showing worship background on external display")
        
        let hostingController = UIHostingController(
            rootView: WorshipBackgroundView(imageName: "serene")
        )
        
        // Configure the hosting controller for optimal external display
        hostingController.view.backgroundColor = .black
        hostingController.view.isOpaque = true
        
        // Simple transition to background
        if let currentController = window.rootViewController {
            UIView.transition(
                with: window,
                duration: 0.1,
                options: [.transitionCrossDissolve],
                animations: {
                    window.rootViewController = hostingController
                },
                completion: { _ in
                    print("Worship background displayed successfully")
                }
            )
        } else {
            // Direct assignment if no current controller
            window.rootViewController = hostingController
            print("Worship background displayed successfully")
        }
        
        window.makeKeyAndVisible()
    }
    
    func nextVerse() {
        guard let hymn = currentHymn, isPresenting else { return }
        
        let maxIndex = hymn.parts.isEmpty ? 0 : hymn.parts.count - 1
        if currentVerseIndex < maxIndex {
            currentVerseIndex += 1
            Task {
                await updateExternalDisplay()
            }
        }
    }
    
    func previousVerse() {
        guard isPresenting else { return }
        
        if currentVerseIndex > 0 {
            currentVerseIndex -= 1
            Task {
                await updateExternalDisplay()
            }
        }
    }
    
    func goToVerse(_ index: Int) {
        guard let hymn = currentHymn, isPresenting else { return }
        
        let maxIndex = hymn.parts.isEmpty ? 0 : hymn.parts.count - 1
        if index >= 0 && index <= maxIndex {
            currentVerseIndex = index
            Task {
                await updateExternalDisplay()
            }
        }
    }
    
    private func createExternalWindow(for scene: UIWindowScene) throws {
        guard externalWindow == nil else { return }
        
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = .black
        window.isHidden = false
        
        externalWindow = window
    }
    
    private func updateExternalDisplay() async {
        guard let window = externalWindow,
              let hymn = currentHymn,
              state.isPresenting else {
            print("Cannot update external display: window=\(externalWindow != nil), hymn=\(currentHymn != nil), state=\(state)")
            return 
        }
        
        print("Updating external display: \(hymn.title), verse \(currentVerseIndex + 1)")
        
        let hostingController = UIHostingController(
            rootView: ExternalPresenterView(
                hymn: hymn,
                verseIndex: currentVerseIndex
            )
        )
        
        // Configure the hosting controller for optimal external display
        hostingController.view.backgroundColor = .black
        hostingController.view.isOpaque = true
        
        // Simple transition for hymn presentation
        if let currentController = window.rootViewController {
            UIView.transition(
                with: window,
                duration: 0.1,
                options: [.transitionCrossDissolve],
                animations: {
                    window.rootViewController = hostingController
                },
                completion: { _ in
                    print("External display updated successfully")
                }
            )
        } else {
            // Direct assignment if no current controller
            window.rootViewController = hostingController
            print("External display updated successfully")
        }
        
        window.makeKeyAndVisible()
    }
    
    var canGoToNextVerse: Bool {
        guard let hymn = currentHymn else { return false }
        let maxIndex = hymn.parts.isEmpty ? 0 : hymn.parts.count - 1
        return currentVerseIndex < maxIndex
    }
    
    var canGoToPreviousVerse: Bool {
        return currentVerseIndex > 0
    }
    
    var currentVerseInfo: String {
        guard let hymn = currentHymn, !hymn.parts.isEmpty else {
            return NSLocalizedString("status.no_lyrics_available", comment: "No verse available status")
        }
        
        let part = hymn.parts[currentVerseIndex]
        if let label = part.label {
            return label
        } else {
            let verseNumber = hymn.parts[0...currentVerseIndex].filter { $0.label == nil }.count
            return String(format: NSLocalizedString("external.verse_number", comment: "Verse number format"), verseNumber)
        }
    }
    
    var totalVerses: Int {
        return currentHymn?.parts.count ?? 0
    }
}
