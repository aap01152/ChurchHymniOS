//
//  SwiftDataManager.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import SwiftUI
import SwiftData
import Foundation
import OSLog

/// Global actor for coordinating all SwiftData operations
@globalActor
actor DataActor {
    static let shared = DataActor()
    
    private init() {}
}

/// Thread-safe SwiftData manager that handles all database operations
@DataActor
final class SwiftDataManager {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "SwiftDataManager")
    
    // Background context for heavy operations
    private lazy var backgroundContext: ModelContext = {
        let context = ModelContext(modelContainer)
        return context
    }()
    
    // Main context for UI operations
    lazy var mainContext: ModelContext = {
        let context = ModelContext(modelContainer)
        return context
    }()
    
    // MARK: - Initialization
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        logger.info("SwiftDataManager initialized successfully")
    }
    
    // MARK: - Core Operations
    
    /// Fetch entities using a descriptor
    func fetch<T>(_ descriptor: FetchDescriptor<T>) async throws -> [T] where T: PersistentModel {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let results = try backgroundContext.fetch(descriptor)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Fetch \(String(describing: T.self)): \(results.count) items in \(duration, format: .fixed(precision: 3))s")
            
            return results
        } catch {
            logger.error("Fetch failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    /// Fetch a single entity by predicate
    func fetchFirst<T>(_ descriptor: FetchDescriptor<T>) async throws -> T? where T: PersistentModel {
        let results = try await fetch(descriptor)
        return results.first
    }
    
    /// Count entities matching a predicate
    func count<T>(for type: T.Type, predicate: Predicate<T>? = nil) async throws -> Int where T: PersistentModel {
        do {
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            let results = try backgroundContext.fetch(descriptor)
            
            logger.info("Count \(String(describing: T.self)): \(results.count) items")
            return results.count
        } catch {
            logger.error("Count failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    /// Insert a new entity
    func insert<T>(_ model: T) async throws where T: PersistentModel {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            backgroundContext.insert(model)
            try backgroundContext.save()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Insert \(String(describing: T.self)) completed in \(duration, format: .fixed(precision: 3))s")
        } catch {
            logger.error("Insert failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.insertFailed(error)
        }
    }
    
    /// Insert multiple entities in batch
    func insertBatch<T>(_ models: [T]) async throws where T: PersistentModel {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            for model in models {
                backgroundContext.insert(model)
            }
            try backgroundContext.save()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Batch insert \(models.count) \(String(describing: T.self)) completed in \(duration, format: .fixed(precision: 3))s")
        } catch {
            logger.error("Batch insert failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.batchInsertFailed(error)
        }
    }
    
    /// Delete an entity
    func delete<T>(_ model: T) async throws where T: PersistentModel {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            backgroundContext.delete(model)
            try backgroundContext.save()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Delete \(String(describing: T.self)) completed in \(duration, format: .fixed(precision: 3))s")
        } catch {
            logger.error("Delete failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.deleteFailed(error)
        }
    }
    
    /// Delete multiple entities matching predicate
    func deleteBatch<T>(type: T.Type, predicate: Predicate<T>) async throws -> Int where T: PersistentModel {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            let modelsToDelete = try backgroundContext.fetch(descriptor)
            
            let deleteCount = modelsToDelete.count
            for model in modelsToDelete {
                backgroundContext.delete(model)
            }
            try backgroundContext.save()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Batch delete \(deleteCount) \(String(describing: T.self)) completed in \(duration, format: .fixed(precision: 3))s")
            
            return deleteCount
        } catch {
            logger.error("Batch delete failed for \(String(describing: T.self)): \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    /// Save changes to the context
    func save() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            if backgroundContext.hasChanges {
                try backgroundContext.save()
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                logger.info("Save completed in \(duration, format: .fixed(precision: 3))s")
            } else {
                logger.info("No changes to save")
            }
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            throw DataLayerError.saveFailed(error)
        }
    }
    
    /// Execute multiple operations in a transaction
    func performTransaction<T>(_ operation: @DataActor @Sendable () async throws -> T) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try await operation()
            try await save()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Transaction completed in \(duration, format: .fixed(precision: 3))s")
            
            return result
        } catch {
            logger.error("Transaction failed: \(error.localizedDescription)")
            // Note: SwiftData doesn't have explicit rollback, but changes won't be saved
            throw DataLayerError.transactionFailed(error)
        }
    }
    
    // MARK: - Context Access
    
    /// Get a fresh context for specific operations
    func withNewContext<T>(_ operation: @DataActor @Sendable (ModelContext) throws -> T) async rethrows -> T {
        let context = ModelContext(modelContainer)
        return try operation(context)
    }
    
    /// Check if context has unsaved changes
    var hasChanges: Bool {
        backgroundContext.hasChanges
    }
    
    // MARK: - Health Check
    
    /// Verify the manager is working correctly
    func performHealthCheck() async throws -> HealthCheckResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Test basic operations
            let hymnCount = try await count(for: Hymn.self)
            let serviceCount = try await count(for: WorshipService.self)
            let serviceHymnCount = try await count(for: ServiceHymn.self)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            let result = HealthCheckResult(
                isHealthy: true,
                hymnCount: hymnCount,
                serviceCount: serviceCount,
                serviceHymnCount: serviceHymnCount,
                responseTime: duration,
                lastChecked: Date()
            )
            
            logger.info("Health check passed: \(hymnCount) hymns, \(serviceCount) services, \(serviceHymnCount) service hymns")
            return result
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            
            return HealthCheckResult(
                isHealthy: false,
                hymnCount: 0,
                serviceCount: 0,
                serviceHymnCount: 0,
                responseTime: CFAbsoluteTimeGetCurrent() - startTime,
                lastChecked: Date(),
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - Health Check Result

struct HealthCheckResult: Sendable {
    let isHealthy: Bool
    let hymnCount: Int
    let serviceCount: Int
    let serviceHymnCount: Int
    let responseTime: TimeInterval
    let lastChecked: Date
    let error: String?
    
    init(isHealthy: Bool, hymnCount: Int, serviceCount: Int, serviceHymnCount: Int, responseTime: TimeInterval, lastChecked: Date, error: String? = nil) {
        self.isHealthy = isHealthy
        self.hymnCount = hymnCount
        self.serviceCount = serviceCount
        self.serviceHymnCount = serviceHymnCount
        self.responseTime = responseTime
        self.lastChecked = lastChecked
        self.error = error
    }
}

// MARK: - Extensions for Convenience

extension SwiftDataManager {
    
    /// Convenience method for fetching all entities of a type
    func fetchAll<T>(_ type: T.Type, sortBy: [SortDescriptor<T>] = []) async throws -> [T] where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(sortBy: sortBy)
        return try await fetch(descriptor)
    }
    
    /// Convenience method for fetching with limit
    func fetchLimited<T>(_ type: T.Type, limit: Int, sortBy: [SortDescriptor<T>] = []) async throws -> [T] where T: PersistentModel {
        var descriptor = FetchDescriptor<T>(sortBy: sortBy)
        descriptor.fetchLimit = limit
        return try await fetch(descriptor)
    }
    
    /// Check if any entities exist for a type
    func exists<T>(for type: T.Type, predicate: Predicate<T>? = nil) async throws -> Bool where T: PersistentModel {
        let count = try await count(for: type, predicate: predicate)
        return count > 0
    }
}
