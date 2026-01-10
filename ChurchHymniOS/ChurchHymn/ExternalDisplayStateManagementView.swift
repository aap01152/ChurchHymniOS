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
            .navigationTitle(NSLocalizedString("external.state_management_title", comment: "State management title"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(NSLocalizedString("external.state_validation_title", comment: "State validation title"), isPresented: $showingValidationResults) {
                Button(NSLocalizedString("btn.ok", comment: "OK")) { }
            } message: {
                VStack(alignment: .leading) {
                    if !validationResults.errors.isEmpty {
                        Text(String(format: NSLocalizedString("external.state_validation_errors", comment: "State validation errors"), validationResults.errors.joined(separator: ", ")))
                    }
                    if !validationResults.warnings.isEmpty {
                        Text(String(format: NSLocalizedString("external.state_validation_warnings", comment: "State validation warnings"), validationResults.warnings.joined(separator: ", ")))
                    }
                    if !validationResults.suggestions.isEmpty {
                        Text(String(format: NSLocalizedString("external.state_validation_suggestions", comment: "State validation suggestions"), validationResults.suggestions.joined(separator: ", ")))
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
                    Text(NSLocalizedString("external.current_state", comment: "Current state label"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(externalDisplayManager.state.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(externalDisplayManager.state.stateColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(NSLocalizedString("external.state_priority", comment: "State priority"))
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
            Text(NSLocalizedString("external.state_capabilities", comment: "State capabilities"))
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                CapabilityRow(title: NSLocalizedString("external.capability.connected", comment: "Connected capability"), isEnabled: externalDisplayManager.state.isConnected)
                CapabilityRow(title: NSLocalizedString("external.capability.presenting", comment: "Presenting capability"), isEnabled: externalDisplayManager.state.isPresenting)
                CapabilityRow(title: NSLocalizedString("external.capability.worship_session", comment: "Worship session capability"), isEnabled: externalDisplayManager.state.isWorshipSession)
                CapabilityRow(title: NSLocalizedString("external.capability.hymn_switching", comment: "Hymn switching capability"), isEnabled: externalDisplayManager.state.supportsHymnSwitching)
                CapabilityRow(title: NSLocalizedString("external.capability.verse_navigation", comment: "Verse navigation capability"), isEnabled: externalDisplayManager.state.supportsVerseNavigation)
                CapabilityRow(title: NSLocalizedString("external.capability.can_start_presentation", comment: "Can start presentation"), isEnabled: externalDisplayManager.state.canStartPresentation)
                CapabilityRow(title: NSLocalizedString("external.capability.can_stop_presentation", comment: "Can stop presentation"), isEnabled: externalDisplayManager.state.canStopPresentation)
                CapabilityRow(title: NSLocalizedString("external.capability.can_present_hymn", comment: "Can present hymn"), isEnabled: externalDisplayManager.state.canPresentHymn)
            }
        }
    }
    
    // MARK: - State Transition Testing
    
    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("external.state_transition_testing", comment: "State transition testing"))
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Target state picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("external.target_state", comment: "Target state"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker(NSLocalizedString("external.target_state", comment: "Target state picker"), selection: $selectedTargetState) {
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
                        Text(String(format: NSLocalizedString("external.transition_status", comment: "Transition status"), canTransition ? NSLocalizedString("external.transition_allowed", comment: "Allowed") : NSLocalizedString("external.transition_blocked", comment: "Blocked")))
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
            Text(NSLocalizedString("external.suggested_actions", comment: "Suggested actions"))
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
            Text(NSLocalizedString("external.state_validation_title", comment: "State validation"))
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: validateCurrentState) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                    Text(NSLocalizedString("external.validate_current_state", comment: "Validate current state"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            if validationResults.hasIssues {
                VStack(alignment: .leading, spacing: 8) {
                    if !validationResults.errors.isEmpty {
                        Label(NSLocalizedString("external.errors_found", comment: "Errors found"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if !validationResults.warnings.isEmpty {
                        Label(NSLocalizedString("external.warnings_found", comment: "Warnings found"), systemImage: "exclamationmark.triangle")
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
            Text(NSLocalizedString("external.recent_transitions", comment: "Recent transitions"))
                .font(.headline)
                .fontWeight(.semibold)
            
            if transitionHistory.isEmpty {
                Text(NSLocalizedString("external.no_recent_transitions", comment: "No recent transitions"))
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
            warnings.append(NSLocalizedString("external.validation.no_display_warning", comment: "No external display connected"))
            suggestions.append(NSLocalizedString("external.validation.connect_display_suggestion", comment: "Connect an external display for presentation features"))
        }
        
        if externalDisplayManager.state.isPresenting && externalDisplayManager.currentHymn == nil {
            errors.append(NSLocalizedString("external.validation.no_hymn_error", comment: "Presenting without a hymn loaded"))
            suggestions.append(NSLocalizedString("external.validation.load_hymn_suggestion", comment: "Load a hymn to continue presentation"))
        }
        
        if externalDisplayManager.state.isWorshipSession && !worshipSessionActive() {
            errors.append(NSLocalizedString("external.validation.worship_mode_error", comment: "Worship mode without worship session"))
            suggestions.append(NSLocalizedString("external.validation.worship_mode_suggestion", comment: "Start a worship session or exit worship mode"))
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
            StateTransition(from: .disconnected, to: .connected, reason: NSLocalizedString("external.transition.display_connected", comment: "Display connected")),
            StateTransition(from: .connected, to: .worshipMode, reason: NSLocalizedString("external.transition.worship_started", comment: "Worship session started")),
            StateTransition(from: .worshipMode, to: .worshipPresenting, reason: NSLocalizedString("external.transition.hymn_presented", comment: "Hymn presented"))
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
