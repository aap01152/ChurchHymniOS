//
//  DataLayerErrors.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation

// MARK: - Data Layer Errors

/// Errors that can occur in the data layer
enum DataLayerError: LocalizedError, Identifiable, Sendable {
    
    // Core SwiftData operations
    case fetchFailed(Error)
    case insertFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case saveFailed(Error)
    case transactionFailed(Error)
    
    // Batch operations
    case batchInsertFailed(Error)
    case batchUpdateFailed(Error)
    case batchDeleteFailed(Error)
    
    // Model container issues
    case containerInitializationFailed(Error)
    case contextCreationFailed(Error)
    case migrationFailed(Error)
    
    // Data validation
    case validationFailed(String)
    case constraintViolation(String)
    case relationshipError(String)
    
    // Concurrency issues
    case concurrencyError(String)
    case deadlockDetected(String)
    case contextMismatch(String)
    
    // Resource issues
    case diskSpaceInsufficient
    case memoryPressure
    case databaseCorrupted(String)
    case permissionDenied
    
    // Network-related (for future cloud sync)
    case networkUnavailable
    case syncConflict(String)
    case cloudSyncFailed(Error)
    
    // MARK: - Identifiable
    
    var id: String {
        switch self {
        case .fetchFailed: return "fetchFailed"
        case .insertFailed: return "insertFailed"
        case .updateFailed: return "updateFailed"
        case .deleteFailed: return "deleteFailed"
        case .saveFailed: return "saveFailed"
        case .transactionFailed: return "transactionFailed"
        case .batchInsertFailed: return "batchInsertFailed"
        case .batchUpdateFailed: return "batchUpdateFailed"
        case .batchDeleteFailed: return "batchDeleteFailed"
        case .containerInitializationFailed: return "containerInitializationFailed"
        case .contextCreationFailed: return "contextCreationFailed"
        case .migrationFailed: return "migrationFailed"
        case .validationFailed: return "validationFailed"
        case .constraintViolation: return "constraintViolation"
        case .relationshipError: return "relationshipError"
        case .concurrencyError: return "concurrencyError"
        case .deadlockDetected: return "deadlockDetected"
        case .contextMismatch: return "contextMismatch"
        case .diskSpaceInsufficient: return "diskSpaceInsufficient"
        case .memoryPressure: return "memoryPressure"
        case .databaseCorrupted: return "databaseCorrupted"
        case .permissionDenied: return "permissionDenied"
        case .networkUnavailable: return "networkUnavailable"
        case .syncConflict: return "syncConflict"
        case .cloudSyncFailed: return "cloudSyncFailed"
        }
    }
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return NSLocalizedString("data.error.fetch_failed", 
                                    comment: "Failed to fetch data from database") + ": \(error.localizedDescription)"
        
        case .insertFailed(let error):
            return NSLocalizedString("data.error.insert_failed", 
                                    comment: "Failed to insert data into database") + ": \(error.localizedDescription)"
        
        case .updateFailed(let error):
            return NSLocalizedString("data.error.update_failed", 
                                    comment: "Failed to update data in database") + ": \(error.localizedDescription)"
        
        case .deleteFailed(let error):
            return NSLocalizedString("data.error.delete_failed", 
                                    comment: "Failed to delete data from database") + ": \(error.localizedDescription)"
        
        case .saveFailed(let error):
            return NSLocalizedString("data.error.save_failed", 
                                    comment: "Failed to save changes to database") + ": \(error.localizedDescription)"
        
        case .transactionFailed(let error):
            return NSLocalizedString("data.error.transaction_failed", 
                                    comment: "Database transaction failed") + ": \(error.localizedDescription)"
        
        case .batchInsertFailed(let error):
            return NSLocalizedString("data.error.batch_insert_failed", 
                                    comment: "Failed to insert multiple records") + ": \(error.localizedDescription)"
        
        case .batchUpdateFailed(let error):
            return NSLocalizedString("data.error.batch_update_failed", 
                                    comment: "Failed to update multiple records") + ": \(error.localizedDescription)"
        
        case .batchDeleteFailed(let error):
            return NSLocalizedString("data.error.batch_delete_failed", 
                                    comment: "Failed to delete multiple records") + ": \(error.localizedDescription)"
        
        case .containerInitializationFailed(let error):
            return NSLocalizedString("data.error.container_init_failed", 
                                    comment: "Failed to initialize database container") + ": \(error.localizedDescription)"
        
        case .contextCreationFailed(let error):
            return NSLocalizedString("data.error.context_creation_failed", 
                                    comment: "Failed to create database context") + ": \(error.localizedDescription)"
        
        case .migrationFailed(let error):
            return NSLocalizedString("data.error.migration_failed", 
                                    comment: "Database migration failed") + ": \(error.localizedDescription)"
        
        case .validationFailed(let details):
            return NSLocalizedString("data.error.validation_failed", 
                                    comment: "Data validation failed") + ": \(details)"
        
        case .constraintViolation(let details):
            return NSLocalizedString("data.error.constraint_violation", 
                                    comment: "Database constraint violation") + ": \(details)"
        
        case .relationshipError(let details):
            return NSLocalizedString("data.error.relationship_error", 
                                    comment: "Database relationship error") + ": \(details)"
        
        case .concurrencyError(let details):
            return NSLocalizedString("data.error.concurrency_error", 
                                    comment: "Concurrency error occurred") + ": \(details)"
        
        case .deadlockDetected(let details):
            return NSLocalizedString("data.error.deadlock_detected", 
                                    comment: "Database deadlock detected") + ": \(details)"
        
        case .contextMismatch(let details):
            return NSLocalizedString("data.error.context_mismatch", 
                                    comment: "Database context mismatch") + ": \(details)"
        
        case .diskSpaceInsufficient:
            return NSLocalizedString("data.error.disk_space_insufficient", 
                                    comment: "Insufficient disk space for database operation")
        
        case .memoryPressure:
            return NSLocalizedString("data.error.memory_pressure", 
                                    comment: "System memory pressure affecting database operations")
        
        case .databaseCorrupted(let details):
            return NSLocalizedString("data.error.database_corrupted", 
                                    comment: "Database corruption detected") + ": \(details)"
        
        case .permissionDenied:
            return NSLocalizedString("data.error.permission_denied", 
                                    comment: "Permission denied for database operation")
        
        case .networkUnavailable:
            return NSLocalizedString("data.error.network_unavailable", 
                                    comment: "Network unavailable for sync operation")
        
        case .syncConflict(let details):
            return NSLocalizedString("data.error.sync_conflict", 
                                    comment: "Sync conflict detected") + ": \(details)"
        
        case .cloudSyncFailed(let error):
            return NSLocalizedString("data.error.cloud_sync_failed", 
                                    comment: "Cloud sync operation failed") + ": \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .fetchFailed:
            return NSLocalizedString("data.error.fetch_failed.reason", 
                                    comment: "The database query could not be completed")
        
        case .insertFailed, .batchInsertFailed:
            return NSLocalizedString("data.error.insert_failed.reason", 
                                    comment: "The new data could not be saved to the database")
        
        case .updateFailed, .batchUpdateFailed:
            return NSLocalizedString("data.error.update_failed.reason", 
                                    comment: "Changes to existing data could not be saved")
        
        case .deleteFailed, .batchDeleteFailed:
            return NSLocalizedString("data.error.delete_failed.reason", 
                                    comment: "Data could not be removed from the database")
        
        case .saveFailed:
            return NSLocalizedString("data.error.save_failed.reason", 
                                    comment: "Pending changes could not be committed to the database")
        
        case .transactionFailed:
            return NSLocalizedString("data.error.transaction_failed.reason", 
                                    comment: "The database transaction could not be completed atomically")
        
        case .containerInitializationFailed:
            return NSLocalizedString("data.error.container_init_failed.reason", 
                                    comment: "The database container could not be initialized properly")
        
        case .contextCreationFailed:
            return NSLocalizedString("data.error.context_creation_failed.reason", 
                                    comment: "A new database context could not be created")
        
        case .migrationFailed:
            return NSLocalizedString("data.error.migration_failed.reason", 
                                    comment: "The database schema migration could not be completed")
        
        case .validationFailed:
            return NSLocalizedString("data.error.validation_failed.reason", 
                                    comment: "The data does not meet the required validation rules")
        
        case .constraintViolation:
            return NSLocalizedString("data.error.constraint_violation.reason", 
                                    comment: "The operation violates database integrity constraints")
        
        case .relationshipError:
            return NSLocalizedString("data.error.relationship_error.reason", 
                                    comment: "The operation affects related data in an invalid way")
        
        case .concurrencyError:
            return NSLocalizedString("data.error.concurrency_error.reason", 
                                    comment: "Multiple threads attempted to modify the same data simultaneously")
        
        case .deadlockDetected:
            return NSLocalizedString("data.error.deadlock_detected.reason", 
                                    comment: "Database operations are waiting for each other indefinitely")
        
        case .contextMismatch:
            return NSLocalizedString("data.error.context_mismatch.reason", 
                                    comment: "The data belongs to a different database context")
        
        case .diskSpaceInsufficient:
            return NSLocalizedString("data.error.disk_space_insufficient.reason", 
                                    comment: "There is not enough free disk space to complete the operation")
        
        case .memoryPressure:
            return NSLocalizedString("data.error.memory_pressure.reason", 
                                    comment: "The system is low on memory and cannot complete database operations")
        
        case .databaseCorrupted:
            return NSLocalizedString("data.error.database_corrupted.reason", 
                                    comment: "The database file has become corrupted and needs to be repaired")
        
        case .permissionDenied:
            return NSLocalizedString("data.error.permission_denied.reason", 
                                    comment: "The app does not have permission to access the database file")
        
        case .networkUnavailable:
            return NSLocalizedString("data.error.network_unavailable.reason", 
                                    comment: "No network connection is available for cloud sync")
        
        case .syncConflict:
            return NSLocalizedString("data.error.sync_conflict.reason", 
                                    comment: "Local and remote data have conflicting changes")
        
        case .cloudSyncFailed:
            return NSLocalizedString("data.error.cloud_sync_failed.reason", 
                                    comment: "The cloud synchronization service is unavailable")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fetchFailed, .insertFailed, .updateFailed, .deleteFailed, .saveFailed:
            return NSLocalizedString("data.error.recovery.retry", 
                                    comment: "Try the operation again. If the problem persists, restart the app.")
        
        case .batchInsertFailed, .batchUpdateFailed, .batchDeleteFailed:
            return NSLocalizedString("data.error.recovery.reduce_batch", 
                                    comment: "Try processing fewer items at once, or restart the app if the problem persists.")
        
        case .transactionFailed:
            return NSLocalizedString("data.error.recovery.transaction", 
                                    comment: "The changes were not saved. Try the operation again.")
        
        case .containerInitializationFailed, .contextCreationFailed:
            return NSLocalizedString("data.error.recovery.restart_app", 
                                    comment: "Restart the app. If the problem persists, contact support.")
        
        case .migrationFailed:
            return NSLocalizedString("data.error.recovery.migration", 
                                    comment: "Restart the app to retry migration. If this fails repeatedly, you may need to reset the app data.")
        
        case .validationFailed:
            return NSLocalizedString("data.error.recovery.validation", 
                                    comment: "Check that all required fields are filled correctly and try again.")
        
        case .constraintViolation:
            return NSLocalizedString("data.error.recovery.constraint", 
                                    comment: "Ensure the data meets all requirements. Check for duplicate entries.")
        
        case .relationshipError:
            return NSLocalizedString("data.error.recovery.relationship", 
                                    comment: "Verify that related data exists and is valid before proceeding.")
        
        case .concurrencyError, .deadlockDetected:
            return NSLocalizedString("data.error.recovery.concurrency", 
                                    comment: "Wait a moment and try the operation again.")
        
        case .contextMismatch:
            return NSLocalizedString("data.error.recovery.context", 
                                    comment: "Restart the app to resolve the data context issue.")
        
        case .diskSpaceInsufficient:
            return NSLocalizedString("data.error.recovery.disk_space", 
                                    comment: "Free up disk space and try again.")
        
        case .memoryPressure:
            return NSLocalizedString("data.error.recovery.memory", 
                                    comment: "Close other apps to free up memory and try again.")
        
        case .databaseCorrupted:
            return NSLocalizedString("data.error.recovery.corruption", 
                                    comment: "Contact support. You may need to reset the app to recover your data.")
        
        case .permissionDenied:
            return NSLocalizedString("data.error.recovery.permission", 
                                    comment: "Restart the app. If the problem persists, reinstall the app.")
        
        case .networkUnavailable:
            return NSLocalizedString("data.error.recovery.network", 
                                    comment: "Check your internet connection and try again.")
        
        case .syncConflict:
            return NSLocalizedString("data.error.recovery.sync_conflict", 
                                    comment: "Choose which version to keep or merge the changes manually.")
        
        case .cloudSyncFailed:
            return NSLocalizedString("data.error.recovery.cloud_sync", 
                                    comment: "Check your internet connection and iCloud settings, then try again.")
        }
    }
}

// MARK: - Repository Errors

/// Errors specific to repository layer operations
enum RepositoryError: LocalizedError, Identifiable, Sendable {
    case entityNotFound(String)
    case duplicateEntity(String)
    case invalidQuery(String)
    case repositoryUnavailable
    case cacheError(String)
    case serializationError(String)
    
    var id: String {
        switch self {
        case .entityNotFound: return "entityNotFound"
        case .duplicateEntity: return "duplicateEntity"
        case .invalidQuery: return "invalidQuery"
        case .repositoryUnavailable: return "repositoryUnavailable"
        case .cacheError: return "cacheError"
        case .serializationError: return "serializationError"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entity):
            return NSLocalizedString("repository.error.entity_not_found", 
                                    comment: "The requested entity was not found") + ": \(entity)"
        
        case .duplicateEntity(let entity):
            return NSLocalizedString("repository.error.duplicate_entity", 
                                    comment: "The entity already exists") + ": \(entity)"
        
        case .invalidQuery(let details):
            return NSLocalizedString("repository.error.invalid_query", 
                                    comment: "The query is invalid") + ": \(details)"
        
        case .repositoryUnavailable:
            return NSLocalizedString("repository.error.unavailable", 
                                    comment: "The repository is currently unavailable")
        
        case .cacheError(let details):
            return NSLocalizedString("repository.error.cache_error", 
                                    comment: "Cache operation failed") + ": \(details)"
        
        case .serializationError(let details):
            return NSLocalizedString("repository.error.serialization_error", 
                                    comment: "Data serialization failed") + ": \(details)"
        }
    }
}

// MARK: - Business Logic Errors

/// Errors related to business logic violations
enum BusinessLogicError: LocalizedError, Identifiable, Sendable {
    case invalidInput(String)
    case businessRuleViolation(String)
    case resourceNotFound(String)
    case permissionDenied(String)
    case operationNotAllowed(String)
    case stateConflict(String)
    case quotaExceeded(String)
    
    var id: String {
        switch self {
        case .invalidInput: return "invalidInput"
        case .businessRuleViolation: return "businessRuleViolation"
        case .resourceNotFound: return "resourceNotFound"
        case .permissionDenied: return "permissionDenied"
        case .operationNotAllowed: return "operationNotAllowed"
        case .stateConflict: return "stateConflict"
        case .quotaExceeded: return "quotaExceeded"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let details):
            return NSLocalizedString("business.error.invalid_input", 
                                    comment: "The provided input is invalid") + ": \(details)"
        
        case .businessRuleViolation(let details):
            return NSLocalizedString("business.error.business_rule_violation", 
                                    comment: "The operation violates business rules") + ": \(details)"
        
        case .resourceNotFound(let resource):
            return NSLocalizedString("business.error.resource_not_found", 
                                    comment: "The requested resource was not found") + ": \(resource)"
        
        case .permissionDenied(let details):
            return NSLocalizedString("business.error.permission_denied", 
                                    comment: "Permission denied for this operation") + ": \(details)"
        
        case .operationNotAllowed(let details):
            return NSLocalizedString("business.error.operation_not_allowed", 
                                    comment: "This operation is not allowed") + ": \(details)"
        
        case .stateConflict(let details):
            return NSLocalizedString("business.error.state_conflict", 
                                    comment: "Operation conflicts with current state") + ": \(details)"
        
        case .quotaExceeded(let details):
            return NSLocalizedString("business.error.quota_exceeded", 
                                    comment: "Resource quota exceeded") + ": \(details)"
        }
    }
}

// MARK: - Error Recovery

/// Protocol for errors that can provide recovery actions
protocol RecoverableError {
    var recoveryActions: [ErrorRecoveryAction] { get }
}

/// Represents a possible recovery action for an error
struct ErrorRecoveryAction: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String?
    let action: @Sendable () async -> Bool
    
    init(title: String, description: String? = nil, action: @escaping @Sendable () async -> Bool) {
        self.title = title
        self.description = description
        self.action = action
    }
}

// MARK: - Error Extensions

extension DataLayerError: RecoverableError {
    var recoveryActions: [ErrorRecoveryAction] {
        switch self {
        case .fetchFailed, .insertFailed, .updateFailed, .deleteFailed, .saveFailed:
            return [
                ErrorRecoveryAction(title: "Retry", description: "Try the operation again") { true },
                ErrorRecoveryAction(title: "Cancel", description: "Cancel the operation") { false }
            ]
        
        case .diskSpaceInsufficient:
            return [
                ErrorRecoveryAction(title: "Free Space", description: "Go to Settings to manage storage") { true }
            ]
        
        case .networkUnavailable:
            return [
                ErrorRecoveryAction(title: "Retry", description: "Check connection and try again") { true },
                ErrorRecoveryAction(title: "Work Offline", description: "Continue without syncing") { true }
            ]
        
        default:
            return [
                ErrorRecoveryAction(title: "OK", description: "Dismiss this error") { false }
            ]
        }
    }
}