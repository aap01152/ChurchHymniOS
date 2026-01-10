//
//  RecoveryActionRow.swift
//  ChurchHymniOS
//
//  Created by paulo on 10/01/2026.
//

import SwiftUI

struct RecoveryActionRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(isEnabled ? .blue : .gray)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .gray)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Button(isEnabled ? "Run" : "N/A") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEnabled)
        }
    }
}

struct DataRecoveryOptionsView: View {
    let integrityResult: IntegrityCheckResult?
    @Binding var isRunningRecovery: Bool
    let onRecoverOrphans: () -> Void
    let onCleanupOrphans: () -> Void
    let onRunIntegrityCheck: () -> Void
    @Binding var isRunningTests: Bool
    let onRunTestSuite: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Data Recovery Tools")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let result = integrityResult {
                        Text("Found \(result.issues.count) data integrity issues")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Issues Summary
                if let result = integrityResult {
                    GroupBox("Issues Found") {
                        VStack(alignment: .leading, spacing: 12) {
                            if result.orphanedServiceHymns > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text("Orphaned Service References: \(result.orphanedServiceHymns)")
                                    Spacer()
                                }
                            }
                            
                            if result.duplicateHymns > 0 {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.orange)
                                    Text("Duplicate Hymns: \(result.duplicateHymns)")
                                    Spacer()
                                }
                            }
                            
                            let criticalCount = result.issues.filter { $0.severity == .critical }.count
                            if criticalCount > 0 {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Text("Critical Issues: \(criticalCount)")
                                    Spacer()
                                }
                            }
                            
                            let warningCount = result.issues.filter { $0.severity == .warning }.count
                            if warningCount > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Warnings: \(warningCount)")
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Recovery Actions
                GroupBox("Recovery Actions") {
                    VStack(spacing: 16) {
                        RecoveryActionRow(
                            icon: "arrow.clockwise",
                            title: "Recover Missing Hymns",
                            description: "Attempt to restore hymns that are referenced in services but missing from the main collection",
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onRecoverOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "trash",
                            title: "Clean Up Orphaned References",
                            description: "Remove service references to hymns that no longer exist",
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onCleanupOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "checkmark.shield",
                            title: "Run Integrity Check",
                            description: "Perform a comprehensive check for data integrity issues",
                            isEnabled: !isRunningRecovery,
                            action: onRunIntegrityCheck
                        )
                        
                        RecoveryActionRow(
                            icon: "testtube.2",
                            title: "Run Test Suite",
                            description: "Execute comprehensive validation tests for all phases",
                            isEnabled: !isRunningTests && !isRunningRecovery,
                            action: onRunTestSuite
                        )
                    }
                    .padding()
                }
                
                if isRunningRecovery {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running recovery operation...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Data Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

