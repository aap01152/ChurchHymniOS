//
//  ExternalDisplayStateManagementView.swift
//  ChurchHymn
//
//  Created by Claude on 29/12/2025.
//  Phase 4: Enhanced State Management Implementation
//

import SwiftUI

/// Advanced state management and debugging view for external display
struct ExternalDisplayStateManagementView: View {
    @EnvironmentObject private var externalDisplayManager: ExternalDisplayManager
    @State private var selectedTargetState: ExternalDisplayState = .connected
    @State private var showingValidationResults = false
    @State private var validationResults: StateValidationResult = .valid
    @State private var transitionHistory: [StateTransition] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current state overview
                    currentStateSection
                    
                    // State capabilities
                    capabilitiesSection
                    
                    // State transition testing
                    transitionSection
                    
                    // Suggested actions
                    actionsSection
                    
                    // State validation
                    validationSection
                    
                    // Transition history
                    historySection
                }
                .padding()
            }
            .navigationTitle("State Management")
            .navigationBarTitleDisplayMode(.inline)
            .alert("State Validation", isPresented: $showingValidationResults) {
                Button("OK") { }
            } message: {
                VStack(alignment: .leading) {
                    if !validationResults.errors.isEmpty {
                        Text("Errors: \(validationResults.errors.joined(separator: ", "))")
                    }
                    if !validationResults.warnings.isEmpty {
                        Text("Warnings: \(validationResults.warnings.joined(separator: ", "))")
                    }
                    if !validationResults.suggestions.isEmpty {
                        Text("Suggestions: \(validationResults.suggestions.joined(separator: ", "))")
                    }
                }
            }
        }
        .onAppear {
            updateTransitionHistory()
        }
    }
    
    // MARK: - State Overview
    
    private var currentStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: externalDisplayManager.state.systemIcon)
                    .font(.title2)
                    .foregroundColor(externalDisplayManager.state.stateColor)
                
                VStack(alignment: .leading) {
                    Text("Current State")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(externalDisplayManager.state.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(externalDisplayManager.state.stateColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(externalDisplayManager.state.transitionPriority)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(externalDisplayManager.state.stateColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Capabilities
    
    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("State Capabilities")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                CapabilityRow(title: "Connected", isEnabled: externalDisplayManager.state.isConnected)
                CapabilityRow(title: "Presenting", isEnabled: externalDisplayManager.state.isPresenting)
                CapabilityRow(title: "Worship Session", isEnabled: externalDisplayManager.state.isWorshipSession)
                CapabilityRow(title: "Hymn Switching", isEnabled: externalDisplayManager.state.supportsHymnSwitching)
                CapabilityRow(title: "Verse Navigation", isEnabled: externalDisplayManager.state.supportsVerseNavigation)
                CapabilityRow(title: "Can Start Presentation", isEnabled: externalDisplayManager.state.canStartPresentation)
                CapabilityRow(title: "Can Stop Presentation", isEnabled: externalDisplayManager.state.canStopPresentation)
                CapabilityRow(title: "Can Present Hymn", isEnabled: externalDisplayManager.state.canPresentHymn)
            }
        }
    }
    
    // MARK: - State Transition Testing
    
    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("State Transition Testing")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Target state picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target State")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Target State", selection: $selectedTargetState) {
                        ForEach(ExternalDisplayState.allCases, id: \.self) { state in
                            HStack {
                                Image(systemName: state.systemIcon)
                                    .foregroundColor(state.stateColor)
                                Text(state.displayName)
                            }
                            .tag(state)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Transition validation
                let canTransition = externalDisplayManager.state.canTransitionTo(selectedTargetState)
                
                HStack {
                    Image(systemName: canTransition ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(canTransition ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text("Transition \(canTransition ? "Allowed" : "Blocked")")
                            .fontWeight(.medium)
                            .foregroundColor(canTransition ? .green : .red)
                        
                        if !canTransition,
                           let errorMessage = externalDisplayManager.state.transitionErrorMessage(to: selectedTargetState) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(canTransition ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Suggested Actions
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(externalDisplayManager.state.suggestedActions, id: \.self) { action in
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        
                        Text(action)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - State Validation
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("State Validation")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: validateCurrentState) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Validate Current State")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            if validationResults.hasIssues {
                VStack(alignment: .leading, spacing: 8) {
                    if !validationResults.errors.isEmpty {
                        Label("Errors Found", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if !validationResults.warnings.isEmpty {
                        Label("Warnings Found", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Transition History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transitions")
                .font(.headline)
                .fontWeight(.semibold)
            
            if transitionHistory.isEmpty {
                Text("No recent transitions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 4) {
                    ForEach(transitionHistory.prefix(5), id: \.timestamp) { transition in
                        HStack {
                            Image(systemName: transition.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(transition.success ? .green : .red)
                            
                            Text(transition.description)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(transition.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateCurrentState() {
        // Simulate state validation with current external display state
        var errors: [String] = []
        var warnings: [String] = []
        var suggestions: [String] = []
        
        // Check for potential issues
        if externalDisplayManager.state == .disconnected {
            warnings.append("No external display connected")
            suggestions.append("Connect an external display for presentation features")
        }
        
        if externalDisplayManager.state.isPresenting && externalDisplayManager.currentHymn == nil {
            errors.append("Presenting without a hymn loaded")
            suggestions.append("Load a hymn to continue presentation")
        }
        
        if externalDisplayManager.state.isWorshipSession && !worshipSessionActive() {
            errors.append("External display in worship mode but no worship session active")
            suggestions.append("Start a worship session or exit worship mode")
        }
        
        validationResults = StateValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors,
            suggestions: suggestions
        )
        
        showingValidationResults = true
    }
    
    private func worshipSessionActive() -> Bool {
        // This would check with WorshipSessionManager
        // For now, return based on state
        return externalDisplayManager.state.isWorshipSession
    }
    
    private func updateTransitionHistory() {
        // In a real implementation, this would be maintained by the ExternalDisplayManager
        // For demo purposes, create some sample transitions
        let now = Date()
        transitionHistory = [
            StateTransition(from: .disconnected, to: .connected, reason: "Display connected"),
            StateTransition(from: .connected, to: .worshipMode, reason: "Worship session started"),
            StateTransition(from: .worshipMode, to: .worshipPresenting, reason: "Hymn presented")
        ].map { transition in
            StateTransition(
                from: transition.from,
                to: transition.to,
                reason: transition.reason,
                success: transition.success,
                error: transition.error
            )
        }
    }
}

// MARK: - Helper Components

struct CapabilityRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isEnabled ? .green : .gray)
            
            Text(title)
                .font(.caption)
                .foregroundColor(isEnabled ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isEnabled ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var externalDisplayManager = ExternalDisplayManager()
        
        var body: some View {
            ExternalDisplayStateManagementView()
                .environmentObject(externalDisplayManager)
                .onAppear {
                    // Set up preview state
                    externalDisplayManager.state = .worshipPresenting
                }
        }
    }
    
    return PreviewWrapper()
}