//
//  ServiceMigration.swift
//  ChurchHymn
//
//  Created by paulo on 01/12/2025.
//

import SwiftUI
import SwiftData
import Foundation

class ServiceMigrationManager {
    
    /// Creates a properly configured ModelContainer with migration support
    static func createModelContainer() -> ModelContainer {
        /*
         Note: SwiftData automatic schema migration
         
         SwiftData automatically handles schema evolution when:
         1. Adding new model classes (WorshipService, ServiceHymn)
         2. Adding optional properties to existing models
         3. The existing data structure remains compatible
         
         Since we're only adding new models without changing Hymn,
         SwiftData should handle this automatically.
         */
        
        // Try the primary approach with automatic migration
        do {
            print("Creating ModelContainer with automatic schema migration...")
            
            let schema = Schema([
                Hymn.self,
                WorshipService.self,
                ServiceHymn.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none // Disable CloudKit for stability during development
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            print("ModelContainer created successfully with automatic migration")
            return container
        } catch {
            print("Primary container creation failed: \(error)")
            return createFallbackContainer()
        }
    }
    
    /// Creates a fallback container if migration fails
    private static func createFallbackContainer() -> ModelContainer {
        do {
            print("Attempting fallback container creation...")
            let schema = Schema([
                Hymn.self,
                WorshipService.self,
                ServiceHymn.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none // Ensure no CloudKit conflicts
            )
            
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            print("Fallback container failed, trying emergency reset...")
            return createEmergencyContainer()
        }
    }
    
    /// Emergency container creation - clears existing data if necessary
    private static func createEmergencyContainer() -> ModelContainer {
        do {
            // This is a last resort - it may result in data loss
            print("WARNING: Creating emergency container - existing data may be lost")
            
            // Try to get the default store URL and remove it
            let url = URL.applicationSupportDirectory.appending(path: "Model.sqlite")
            try? FileManager.default.removeItem(at: url)
            
            let schema = Schema([
                Hymn.self,
                WorshipService.self,
                ServiceHymn.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            print("Emergency container created successfully")
            return container
        } catch {
            fatalError("Failed to create emergency ModelContainer: \(error)")
        }
    }
    
    /// Performs any necessary data migrations after model updates
    static func performMigrations(context: ModelContext) {
        do {
            // Check if this is a first-time setup or migration
            let existingServices = try context.fetch(FetchDescriptor<WorshipService>())
            let existingServiceHymns = try context.fetch(FetchDescriptor<ServiceHymn>())
            
            print("Migration check: Found \(existingServices.count) services and \(existingServiceHymns.count) service hymns")
            
            // If no services exist but hymns do, this might be a first-time setup
            let existingHymns = try context.fetch(FetchDescriptor<Hymn>())
            if existingServices.isEmpty && !existingHymns.isEmpty {
                print("First-time service setup detected with \(existingHymns.count) existing hymns")
                // Could create a default service here if needed
            }
            
            // Validate data integrity
            try validateServiceDataIntegrity(context: context)
            
            print("Service migration completed successfully")
        } catch {
            print("Service migration error: \(error)")
            // Don't fail the app, but log the error
        }
    }
    
    /// Validates that all service data is consistent
    private static func validateServiceDataIntegrity(context: ModelContext) throws {
        // Check for orphaned service hymns (references to non-existent services)
        let allServiceHymns = try context.fetch(FetchDescriptor<ServiceHymn>())
        let allServices = try context.fetch(FetchDescriptor<WorshipService>())
        let serviceIds = Set(allServices.map { $0.id })
        
        var orphanedServiceHymns: [ServiceHymn] = []
        
        for serviceHymn in allServiceHymns {
            if !serviceIds.contains(serviceHymn.serviceId) {
                orphanedServiceHymns.append(serviceHymn)
            }
        }
        
        // Clean up orphaned service hymns
        if !orphanedServiceHymns.isEmpty {
            print("Cleaning up \(orphanedServiceHymns.count) orphaned service hymns")
            for orphan in orphanedServiceHymns {
                context.delete(orphan)
            }
            try context.save()
        }
        
        // Validate service hymn ordering
        try validateServiceHymnOrdering(context: context, services: allServices)
        
        // Ensure only one active service
        try validateActiveServices(context: context, services: allServices)
    }
    
    /// Validates and fixes service hymn ordering
    private static func validateServiceHymnOrdering(context: ModelContext, services: [WorshipService]) throws {
        for service in services {
            let serviceHymns = try context.fetch(FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                },
                sortBy: [SortDescriptor(\.order)]
            ))
            
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
                print("Fixing order for service: \(service.displayTitle)")
                for (correctOrder, serviceHymn) in serviceHymns.enumerated() {
                    serviceHymn.updateOrder(correctOrder)
                }
                service.updateTimestamp()
            }
        }
        
        try context.save()
    }
    
    /// Ensures only one service is marked as active
    private static func validateActiveServices(context: ModelContext, services: [WorshipService]) throws {
        let activeServices = services.filter { $0.isActive }
        
        if activeServices.count > 1 {
            print("Found multiple active services, keeping only the most recent")
            // Sort by date and keep only the most recent as active
            let sortedActive = activeServices.sorted { $0.date > $1.date }
            
            for (index, service) in sortedActive.enumerated() {
                service.setActive(index == 0) // Only the first (most recent) stays active
            }
            
            try context.save()
        }
    }
}

// MARK: - Service Data Validation Extensions

extension ServiceOperations {
    /// Validates the integrity of service data
    func validateDataIntegrity() async -> Result<String, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Validating service data..."
            operationProgress = 0.0
        }
        
        do {
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Checking services..."
            }
            
            ServiceMigrationManager.performMigrations(context: context)
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Validation complete"
                isLoading = false
            }
            
            return .success("Data validation completed successfully")
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.contextError(error.localizedDescription)
            }
            return .failure(ServiceError.contextError(error.localizedDescription))
        }
    }
}

// MARK: - Migration Helper Functions

extension ServiceOperations {
    /// Creates a default "Today's Service" if none exists
    func ensureTodaysServiceExists() async -> WorshipService? {
        // Check if there's already an active service
        if let activeService = getActiveService() {
            return activeService
        }
        
        // Check if there's a service for today
        let today = Date()
        let calendar = Calendar.current
        let services = getAllServices()
        
        for service in services {
            if calendar.isDate(service.date, inSameDayAs: today) {
                // Found a service for today, make it active
                let result = await setActiveService(service)
                switch result {
                case .success:
                    return service
                case .failure:
                    break
                }
            }
        }
        
        // No service for today exists, create one
        let result = await createTodaysService()
        switch result {
        case .success(let service):
            _ = await setActiveService(service)
            return service
        case .failure:
            return nil
        }
    }
}