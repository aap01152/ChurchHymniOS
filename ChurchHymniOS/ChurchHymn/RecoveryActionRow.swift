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
            
            Button(isEnabled ? NSLocalizedString("btn.run", comment: "Run") : NSLocalizedString("status.not_available", comment: "Not available")) {
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
                    
                    Text(NSLocalizedString("recovery.tools_title", comment: "Data recovery tools"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let result = integrityResult {
                        Text(String(format: NSLocalizedString("recovery.issues_found", comment: "Data integrity issues found"), result.issues.count))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Issues Summary
                if let result = integrityResult {
                    GroupBox(NSLocalizedString("recovery.issues_found_title", comment: "Issues found title")) {
                        VStack(alignment: .leading, spacing: 12) {
                            if result.orphanedServiceHymns > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                    Text(String(format: NSLocalizedString("recovery.orphaned_references", comment: "Orphaned service references"), result.orphanedServiceHymns))
                                    Spacer()
                                }
                            }
                            
                            if result.duplicateHymns > 0 {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.orange)
                                    Text(String(format: NSLocalizedString("recovery.duplicate_hymns", comment: "Duplicate hymns"), result.duplicateHymns))
                                    Spacer()
                                }
                            }
                            
                            let criticalCount = result.issues.filter { $0.severity == .critical }.count
                            if criticalCount > 0 {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Text(String(format: NSLocalizedString("recovery.critical_issues", comment: "Critical issues"), criticalCount))
                                    Spacer()
                                }
                            }
                            
                            let warningCount = result.issues.filter { $0.severity == .warning }.count
                            if warningCount > 0 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text(String(format: NSLocalizedString("recovery.warnings", comment: "Warnings"), warningCount))
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Recovery Actions
                GroupBox(NSLocalizedString("recovery.actions_title", comment: "Recovery actions title")) {
                    VStack(spacing: 16) {
                        RecoveryActionRow(
                            icon: "arrow.clockwise",
                            title: NSLocalizedString("recovery.action.recover_missing_hymns", comment: "Recover missing hymns"),
                            description: NSLocalizedString("recovery.action.recover_missing_hymns_desc", comment: "Recover missing hymns description"),
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onRecoverOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "trash",
                            title: NSLocalizedString("recovery.action.cleanup_orphaned", comment: "Clean up orphaned references"),
                            description: NSLocalizedString("recovery.action.cleanup_orphaned_desc", comment: "Clean up orphaned references description"),
                            isEnabled: !isRunningRecovery && (integrityResult?.orphanedServiceHymns ?? 0) > 0,
                            action: onCleanupOrphans
                        )
                        
                        Divider()
                        
                        RecoveryActionRow(
                            icon: "checkmark.shield",
                            title: NSLocalizedString("recovery.action.run_integrity_check", comment: "Run integrity check"),
                            description: NSLocalizedString("recovery.action.run_integrity_check_desc", comment: "Run integrity check description"),
                            isEnabled: !isRunningRecovery,
                            action: onRunIntegrityCheck
                        )
                        
                        RecoveryActionRow(
                            icon: "testtube.2",
                            title: NSLocalizedString("recovery.action.run_test_suite", comment: "Run test suite"),
                            description: NSLocalizedString("recovery.action.run_test_suite_desc", comment: "Run test suite description"),
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
                        Text(NSLocalizedString("recovery.running_operation", comment: "Running recovery operation"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(NSLocalizedString("nav.data_recovery", comment: "Data recovery title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("btn.close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
