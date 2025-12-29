//
//  AutoPresentManager.swift
//  ChurchHymn
//
//  Created by Claude on 29/12/2025.
//

import SwiftUI
import UIKit
import Combine
import Foundation

/// Manager for auto-present mode functionality
/// Automatically presents hymns when user stays on them for a configured duration
@MainActor
final class AutoPresentManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether auto-present mode is enabled
    @Published var isEnabled: Bool = false
    
    /// Delay before auto-presenting (in seconds)
    @Published var presentDelay: TimeInterval = 3.0
    
    /// Current countdown value for display
    @Published var countdownValue: Int = 0
    
    /// Whether countdown is active
    @Published var isCountingDown: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    private var currentHymn: Hymn?
    private var worshipSessionManager: WorshipSessionManager?
    
    // MARK: - Configuration
    
    /// Available delay options (in seconds)
    static let delayOptions: [TimeInterval] = [2.0, 3.0, 5.0, 7.0, 10.0]
    
    /// Delay option labels
    static let delayLabels: [TimeInterval: String] = [
        2.0: "2 seconds",
        3.0: "3 seconds", 
        5.0: "5 seconds",
        7.0: "7 seconds",
        10.0: "10 seconds"
    ]
    
    // MARK: - Public Methods
    
    /// Setup auto-present manager with worship session manager
    func setup(worshipSessionManager: WorshipSessionManager) {
        self.worshipSessionManager = worshipSessionManager
    }
    
    /// Start auto-present timer for a hymn
    func startTimer(for hymn: Hymn) {
        guard isEnabled,
              let worshipSessionManager = worshipSessionManager,
              worshipSessionManager.isWorshipSessionActive,
              worshipSessionManager.canPresentHymn(hymn) else {
            return
        }
        
        // Don't start timer if hymn is already being presented
        if let currentWorshipHymn = worshipSessionManager.currentWorshipHymn,
           hymn.id == currentWorshipHymn.id {
            return
        }
        
        // Cancel existing timer
        cancelTimer()
        
        currentHymn = hymn
        isCountingDown = true
        countdownValue = Int(presentDelay)
        
        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.countdownValue -= 1
            
            if self.countdownValue <= 0 {
                timer.invalidate()
                Task { @MainActor in
                    await self.executeAutoPresent()
                }
            }
        }
        
        print("🕒 Auto-present timer started for: \(hymn.title) (\(Int(presentDelay))s)")
    }
    
    /// Cancel auto-present timer
    func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        countdownValue = 0
        currentHymn = nil
        
        print("⏹️ Auto-present timer cancelled")
    }
    
    /// Pause auto-present timer
    func pauseTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        // Keep isCountingDown true to show paused state
        
        print("⏸️ Auto-present timer paused")
    }
    
    /// Resume auto-present timer
    func resumeTimer() {
        guard isCountingDown,
              countdownValue > 0,
              let hymn = currentHymn else {
            return
        }
        
        // Restart timer with remaining time
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.countdownValue -= 1
            
            if self.countdownValue <= 0 {
                timer.invalidate()
                Task { @MainActor in
                    await self.executeAutoPresent()
                }
            }
        }
        
        print("▶️ Auto-present timer resumed for: \(hymn.title) (\(countdownValue)s remaining)")
    }
    
    /// Toggle auto-present mode
    func toggle() {
        isEnabled.toggle()
        
        if !isEnabled {
            cancelTimer()
        }
        
        print("🔄 Auto-present mode: \(isEnabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    /// Execute auto-present action
    private func executeAutoPresent() async {
        guard let hymn = currentHymn,
              let worshipSessionManager = worshipSessionManager else {
            return
        }
        
        isCountingDown = false
        countdownValue = 0
        
        do {
            print("🎵 Auto-presenting hymn: \(hymn.title)")
            try await worshipSessionManager.presentCurrentlyViewedHymn(hymn)
            
            // Provide haptic feedback for auto-present
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
        } catch {
            print("❌ Auto-present failed: \(error.localizedDescription)")
            
            // Provide error haptic feedback
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
}

/// Settings view for auto-present configuration
struct AutoPresentSettingsView: View {
    @ObservedObject var autoPresentManager: AutoPresentManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Auto-Present", isOn: $autoPresentManager.isEnabled)
                        .onChange(of: autoPresentManager.isEnabled) { _ in
                            if !autoPresentManager.isEnabled {
                                autoPresentManager.cancelTimer()
                            }
                        }
                } header: {
                    Text("Auto-Present Mode")
                }
                
                if autoPresentManager.isEnabled {
                    Section {
                        Picker("Present Delay", selection: $autoPresentManager.presentDelay) {
                            ForEach(AutoPresentManager.delayOptions, id: \.self) { delay in
                                Text(AutoPresentManager.delayLabels[delay] ?? "\(Int(delay)) seconds")
                                    .tag(delay)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Settings")
                    } footer: {
                        Text("Hymns will automatically present after staying on them for the selected duration during worship sessions.")
                    }
                    
                    Section {
                        Label("Navigate to a hymn during worship", systemImage: "1.circle.fill")
                        Label("Countdown timer starts automatically", systemImage: "2.circle.fill")  
                        Label("Hymn presents when timer reaches zero", systemImage: "3.circle.fill")
                        Label("Timer cancels when navigating away", systemImage: "4.circle.fill")
                    } header: {
                        Text("How It Works")
                    } footer: {
                        Text("Auto-present only works during active worship sessions and when an external display is connected.")
                    }
                }
            }
            .navigationTitle("Auto-Present Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Countdown overlay view for auto-present mode
struct AutoPresentCountdownOverlay: View {
    @ObservedObject var autoPresentManager: AutoPresentManager
    let hymn: Hymn?
    
    var body: some View {
        if autoPresentManager.isCountingDown,
           let hymn = hymn {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Countdown circle
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.3), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(autoPresentManager.countdownValue) / CGFloat(autoPresentManager.presentDelay))
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: autoPresentManager.countdownValue)
                        
                        Text("\(autoPresentManager.countdownValue)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-presenting...")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Text(hymn.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Cancel button
                    Button(action: autoPresentManager.cancelTimer) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: autoPresentManager.isCountingDown)
        }
    }
}