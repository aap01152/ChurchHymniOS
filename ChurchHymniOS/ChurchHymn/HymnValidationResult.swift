//
//  HymnValidationResult.swift
//  ChurchHymniOS
//
//  Created by paulo on 10/01/2026.
//

import Foundation

/// Result of hymn validation operations
enum HymnValidationResult {
    case success
    case warning(String)
    case failure(String)
    
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .warning, .failure: return false
        }
    }
    
    var message: String? {
        switch self {
        case .success: return nil
        case .warning(let msg), .failure(let msg): return msg
        }
    }
}

/// Transaction result for atomic operations
enum HymnTransactionResult {
    case success(Hymn)
    case failure(String)
    case rollback(String)
}

/// Data integrity issues found during checks
struct DataIntegrityIssue {
    let type: IssueType
    let description: String
    let severity: IssueSeverity
    let affectedHymnId: UUID?
    let serviceId: UUID?
    
    enum IssueType {
        case orphanedServiceHymn
        case missingHymn
        case duplicateHymn
        case corruptedData
        case inconsistentState
    }
    
    enum IssueSeverity {
        case critical   // Data corruption that must be fixed
        case warning    // Inconsistencies that should be addressed
        case info       // Minor issues or suggestions
    }
}

/// Result of data integrity check
struct IntegrityCheckResult {
    let issues: [DataIntegrityIssue]
    let checkedHymns: Int
    let checkedServices: Int
    let orphanedServiceHymns: Int
    let duplicateHymns: Int
    
    var hasCriticalIssues: Bool {
        issues.contains { $0.severity == .critical }
    }
    
    var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }
    
    var isHealthy: Bool {
        issues.isEmpty
    }
}

/// Recovery operation result
enum RecoveryResult {
    case success(recoveredCount: Int, message: String)
    case partialSuccess(recoveredCount: Int, failedCount: Int, message: String)
    case failure(String)
}
