//
//  MigrationUtilities.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import SwiftUI
import SwiftData
import Foundation
import OSLog

// MARK: - Migration Manager

/// Manages data migrations and integrity checks for the new architecture
@DataActor
final class MigrationManager {
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "MigrationManager")
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Main Migration Entry Point
    
    /// Performs all necessary migrations for the current app version
    func performMigrations() async throws {
        logger.info("Starting migration process...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Phase 1: Data integrity validation
            try await validateDataIntegrity()
            
            // Phase 2: Schema migrations
            try await performSchemaMigrations()
            
            // Phase 3: Data cleanup and optimization
            try await performDataCleanup()
            
            // Phase 4: Index optimization
            try await optimizeDataStructures()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Migration completed successfully in \(duration, format: .fixed(precision: 3))s")
            
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            throw DataLayerError.migrationFailed(error)
        }
    }
    
    // MARK: - Data Integrity Validation
    
    /// Validates the integrity of existing data
    func validateDataIntegrity() async throws {
        logger.info("Validating data integrity...")
        
        // Check for orphaned service hymns
        try await cleanupOrphanedServiceHymns()
        
        // Validate service hymn ordering
        try await validateServiceHymnOrdering()
        
        // Ensure only one active service
        try await validateActiveServices()
        
        // Validate model versions
        try await validateModelVersions()
        
        logger.info("Data integrity validation completed")
    }
    
    /// Removes service hymns that reference non-existent services or hymns
    private func cleanupOrphanedServiceHymns() async throws {
        logger.info("Checking for orphaned service hymns...")
        
        let allServiceHymns = try await dataManager.fetchAll(ServiceHymn.self)
        let allServices = try await dataManager.fetchAll(WorshipService.self)
        let allHymns = try await dataManager.fetchAll(Hymn.self)
        
        let serviceIds = Set(allServices.map { $0.id })
        let hymnIds = Set(allHymns.map { $0.id })
        
        var orphanedCount = 0
        
        for serviceHymn in allServiceHymns {
            var isOrphaned = false
            
            // Check if service exists
            if !serviceIds.contains(serviceHymn.serviceId) {
                logger.warning("Found orphaned service hymn - invalid service ID: \(serviceHymn.serviceId)")
                isOrphaned = true
            }
            
            // Check if hymn exists
            if !hymnIds.contains(serviceHymn.hymnId) {
                logger.warning("Found orphaned service hymn - invalid hymn ID: \(serviceHymn.hymnId)")
                isOrphaned = true
            }
            
            if isOrphaned {
                try await dataManager.delete(serviceHymn)
                orphanedCount += 1
            }
        }
        
        if orphanedCount > 0 {
            logger.info("Cleaned up \(orphanedCount) orphaned service hymns")
        }
    }
    
    /// Validates and fixes service hymn ordering
    private func validateServiceHymnOrdering() async throws {
        logger.info("Validating service hymn ordering...")
        
        let allServices = try await dataManager.fetchAll(WorshipService.self)
        var fixedServices = 0
        
        for service in allServices {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                },
                sortBy: [SortDescriptor(\.order)]
            )
            
            let serviceHymns = try await dataManager.fetch(descriptor)
            
            // Check if ordering is sequential starting from 0
            var needsReordering = false
            for (expectedOrder, serviceHymn) in serviceHymns.enumerated() {
                if serviceHymn.order != expectedOrder {
                    needsReordering = true
                    break
                }
            }
            
            // Fix ordering if needed
            if needsReordering {
                logger.info("Fixing ordering for service: \(service.displayTitle)")
                
                try await dataManager.performTransaction {
                    for (correctOrder, serviceHymn) in serviceHymns.enumerated() {
                        serviceHymn.updateOrder(correctOrder)
                    }
                    service.updateTimestamp()
                }
                
                fixedServices += 1
            }
        }
        
        if fixedServices > 0 {
            logger.info("Fixed ordering for \(fixedServices) services")
        }
    }
    
    /// Ensures only one service is marked as active
    private func validateActiveServices() async throws {
        logger.info("Validating active services...")
        
        let descriptor = FetchDescriptor<WorshipService>(
            predicate: #Predicate<WorshipService> { service in
                service.isActive == true
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let activeServices = try await dataManager.fetch(descriptor)
        
        if activeServices.count > 1 {
            logger.warning("Found \(activeServices.count) active services, keeping only the most recent")
            
            try await dataManager.performTransaction {
                for (index, service) in activeServices.enumerated() {
                    service.setActive(index == 0) // Only the first (most recent) stays active
                }
            }
            
            logger.info("Fixed active service state - kept most recent active")
        }
    }
    
    /// Validates model versions and performs version-specific migrations
    private func validateModelVersions() async throws {
        logger.info("Validating model versions...")
        
        // Check Hymn model versions
        let hymns = try await dataManager.fetchAll(Hymn.self)
        for hymn in hymns {
            if hymn.modelVersion < 2 {
                logger.info("Upgrading hymn model version from \(hymn.modelVersion) to 2: \(hymn.title)")
                hymn.modelVersion = 2
            }
        }
        
        // Check WorshipService model versions
        let services = try await dataManager.fetchAll(WorshipService.self)
        for service in services {
            if service.modelVersion < 1 {
                logger.info("Upgrading service model version from \(service.modelVersion) to 1: \(service.displayTitle)")
                service.modelVersion = 1
            }
        }
        
        // Check ServiceHymn model versions
        let serviceHymns = try await dataManager.fetchAll(ServiceHymn.self)
        for serviceHymn in serviceHymns {
            if serviceHymn.modelVersion < 1 {
                logger.info("Upgrading service hymn model version from \(serviceHymn.modelVersion) to 1")
                serviceHymn.modelVersion = 1
            }
        }
        
        try await dataManager.save()
        logger.info("Model version validation completed")
    }
    
    // MARK: - Schema Migrations
    
    /// Performs schema migrations for new features
    func performSchemaMigrations() async throws {
        logger.info("Performing schema migrations...")
        
        // Add future schema migration logic here
        // For now, this is a placeholder for when new model fields are added
        
        logger.info("Schema migrations completed")
    }
    
    // MARK: - Data Cleanup
    
    /// Performs data cleanup and optimization
    func performDataCleanup() async throws {
        logger.info("Performing data cleanup...")
        
        // Remove empty/invalid hymns
        try await cleanupInvalidHymns()
        
        // Remove duplicate service hymns
        try await removeDuplicateServiceHymns()
        
        // Cleanup old temporary data
        try await cleanupTemporaryData()
        
        logger.info("Data cleanup completed")
    }
    
    /// Removes hymns with empty titles or other invalid data
    private func cleanupInvalidHymns() async throws {
        let descriptor = FetchDescriptor<Hymn>(
            predicate: #Predicate<Hymn> { hymn in
                hymn.title.isEmpty
            }
        )
        
        let invalidHymns = try await dataManager.fetch(descriptor)
        
        if !invalidHymns.isEmpty {
            logger.info("Removing \(invalidHymns.count) invalid hymns")
            
            for hymn in invalidHymns {
                // First, remove any service hymns that reference this invalid hymn
                let serviceHymnDescriptor = FetchDescriptor<ServiceHymn>(
                    predicate: #Predicate<ServiceHymn> { serviceHymn in
                        serviceHymn.hymnId == hymn.id
                    }
                )
                
                let relatedServiceHymns = try await dataManager.fetch(serviceHymnDescriptor)
                for serviceHymn in relatedServiceHymns {
                    try await dataManager.delete(serviceHymn)
                }
                
                // Then remove the invalid hymn
                try await dataManager.delete(hymn)
            }
        }
    }
    
    /// Removes duplicate service hymns (same hymn in same service)
    private func removeDuplicateServiceHymns() async throws {
        logger.info("Checking for duplicate service hymns...")
        
        let allServiceHymns = try await dataManager.fetchAll(ServiceHymn.self)
        
        // Group by service and hymn
        var serviceHymnMap: [String: [ServiceHymn]] = [:]
        
        for serviceHymn in allServiceHymns {
            let key = "\(serviceHymn.serviceId)_\(serviceHymn.hymnId)"
            if serviceHymnMap[key] == nil {
                serviceHymnMap[key] = []
            }
            serviceHymnMap[key]!.append(serviceHymn)
        }
        
        var duplicatesRemoved = 0
        
        for (_, serviceHymns) in serviceHymnMap {
            if serviceHymns.count > 1 {
                // Keep the first one (earliest added), remove the rest
                let sortedServiceHymns = serviceHymns.sorted { $0.addedAt < $1.addedAt }
                
                for i in 1..<sortedServiceHymns.count {
                    try await dataManager.delete(sortedServiceHymns[i])
                    duplicatesRemoved += 1
                }
            }
        }
        
        if duplicatesRemoved > 0 {
            logger.info("Removed \(duplicatesRemoved) duplicate service hymns")
        }
    }
    
    /// Cleanup any temporary data that might exist
    private func cleanupTemporaryData() async throws {
        // This is a placeholder for future temporary data cleanup
        // For example, incomplete imports, cached data, etc.
        logger.info("Temporary data cleanup completed")
    }
    
    // MARK: - Data Structure Optimization
    
    /// Optimizes data structures for better performance
    func optimizeDataStructures() async throws {
        logger.info("Optimizing data structures...")
        
        // Pre-fetch commonly used data combinations
        try await warmupDataCaches()
        
        // Validate relationship consistency
        try await validateRelationships()
        
        logger.info("Data structure optimization completed")
    }
    
    /// Warmup data caches for better performance
    private func warmupDataCaches() async throws {
        // Pre-fetch active service and its hymns
        if let activeService = try await getActiveService() {
            _ = try await getServiceHymns(for: activeService.id)
        }
        
        // Pre-fetch recently used hymns
        var recentDescriptor = FetchDescriptor<Hymn>(
            sortBy: [SortDescriptor(\Hymn.title, order: .forward)]
        )
        recentDescriptor.fetchLimit = 50
        _ = try await dataManager.fetch(recentDescriptor)
    }
    
    /// Validates relationship consistency
    private func validateRelationships() async throws {
        // Ensure all service hymns have valid references
        let allServiceHymns = try await dataManager.fetchAll(ServiceHymn.self)
        
        for serviceHymn in allServiceHymns {
            // Verify service exists
            let service = try await getService(by: serviceHymn.serviceId)
            guard service != nil else {
                logger.error("ServiceHymn \(serviceHymn.id) references non-existent service \(serviceHymn.serviceId)")
                continue
            }
            
            // Verify hymn exists
            let hymn = try await getHymn(by: serviceHymn.hymnId)
            guard hymn != nil else {
                logger.error("ServiceHymn \(serviceHymn.id) references non-existent hymn \(serviceHymn.hymnId)")
                continue
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getActiveService() async throws -> WorshipService? {
        let descriptor = FetchDescriptor<WorshipService>(
            predicate: #Predicate<WorshipService> { service in
                service.isActive == true
            }
        )
        return try await dataManager.fetchFirst(descriptor)
    }
    
    private func getServiceHymns(for serviceId: UUID) async throws -> [ServiceHymn] {
        let descriptor = FetchDescriptor<ServiceHymn>(
            predicate: #Predicate<ServiceHymn> { serviceHymn in
                serviceHymn.serviceId == serviceId
            },
            sortBy: [SortDescriptor(\.order)]
        )
        return try await dataManager.fetch(descriptor)
    }
    
    private func getService(by id: UUID) async throws -> WorshipService? {
        let descriptor = FetchDescriptor<WorshipService>(
            predicate: #Predicate<WorshipService> { service in
                service.id == id
            }
        )
        return try await dataManager.fetchFirst(descriptor)
    }
    
    private func getHymn(by id: UUID) async throws -> Hymn? {
        let descriptor = FetchDescriptor<Hymn>(
            predicate: #Predicate<Hymn> { hymn in
                hymn.id == id
            }
        )
        return try await dataManager.fetchFirst(descriptor)
    }
}

// MARK: - Migration Coordinator

/// Coordinates the migration process and provides status updates
@MainActor
final class MigrationCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPerformingMigration = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationMessage = ""
    @Published var migrationError: DataLayerError?
    @Published var migrationCompleted = false
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "MigrationCoordinator")
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Public Methods
    
    /// Performs the migration with progress updates
    func performMigration() async {
        await MainActor.run {
            isPerformingMigration = true
            migrationProgress = 0.0
            migrationMessage = "Starting migration..."
            migrationError = nil
            migrationCompleted = false
        }
        
        do {
            let migrationManager = await MigrationManager(dataManager: dataManager)
            
            // Phase 1: Data integrity validation (25%)
            await updateProgress(0.1, "Validating data integrity...")
            try await migrationManager.validateDataIntegrity()
            await updateProgress(0.25, "Data integrity validation completed")
            
            // Phase 2: Schema migrations (50%)
            await updateProgress(0.3, "Performing schema migrations...")
            try await migrationManager.performSchemaMigrations()
            await updateProgress(0.5, "Schema migrations completed")
            
            // Phase 3: Data cleanup (75%)
            await updateProgress(0.55, "Cleaning up data...")
            try await migrationManager.performDataCleanup()
            await updateProgress(0.75, "Data cleanup completed")
            
            // Phase 4: Optimization (100%)
            await updateProgress(0.8, "Optimizing data structures...")
            try await migrationManager.optimizeDataStructures()
            await updateProgress(1.0, "Migration completed successfully!")
            
            await MainActor.run {
                migrationCompleted = true
                isPerformingMigration = false
            }
            
            logger.info("Migration coordinator completed successfully")
            
        } catch let error as DataLayerError {
            await MainActor.run {
                migrationError = error
                isPerformingMigration = false
                migrationMessage = "Migration failed: \(error.localizedDescription)"
            }
            
            logger.error("Migration coordinator failed: \(error.localizedDescription)")
            
        } catch {
            let dataLayerError = DataLayerError.migrationFailed(error)
            await MainActor.run {
                migrationError = dataLayerError
                isPerformingMigration = false
                migrationMessage = "Migration failed: \(error.localizedDescription)"
            }
            
            logger.error("Migration coordinator failed with unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// Updates migration progress
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            migrationProgress = progress
            migrationMessage = message
        }
        
        // Small delay to allow UI updates
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    /// Resets migration state
    func resetMigrationState() {
        isPerformingMigration = false
        migrationProgress = 0.0
        migrationMessage = ""
        migrationError = nil
        migrationCompleted = false
    }
}