//
//  ServiceHymnRepository.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation
import SwiftData
import OSLog

/// Thread-safe repository for service-hymn relationship data access operations
@DataActor
final class ServiceHymnRepository: ServiceHymnRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let cache: ServiceHymnCache
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ServiceHymnRepository")
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager, cache: ServiceHymnCache = ServiceHymnCache()) {
        self.dataManager = dataManager
        self.cache = cache
        logger.info("ServiceHymnRepository initialized")
    }
    
    // MARK: - BaseRepositoryProtocol
    
    func healthCheck() async throws -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Test basic operations
            let count = try await dataManager.count(for: ServiceHymn.self)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.info("Health check passed: \(count) service hymns, response time: \(duration, format: .fixed(precision: 3))s")
            return true
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            throw RepositoryError.repositoryUnavailable
        }
    }
    
    func clearCache() async throws {
        await cache.clearAll()
        logger.info("ServiceHymn cache cleared")
    }
    
    // MARK: - Basic CRUD Operations
    
    func getAllServiceHymns() async throws -> [ServiceHymn] {
        logger.info("Fetching all service hymns")
        
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                sortBy: [
                    SortDescriptor(\.serviceId),
                    SortDescriptor(\.order)
                ]
            )
            
            let serviceHymns = try await dataManager.fetch(descriptor)
            logger.info("Retrieved \(serviceHymns.count) service hymns")
            return serviceHymns
        } catch {
            logger.error("Failed to fetch all service hymns: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServiceHymn(by id: UUID) async throws -> ServiceHymn? {
        logger.info("Fetching service hymn by ID: \(id)")
        
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.id == id
                }
            )
            
            let serviceHymn = try await dataManager.fetchFirst(descriptor)
            
            if let serviceHymn = serviceHymn {
                logger.info("Service hymn found: \(serviceHymn.id)")
            } else {
                logger.info("Service hymn not found with ID: \(id)")
            }
            
            return serviceHymn
        } catch {
            logger.error("Failed to fetch service hymn by ID: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func createServiceHymn(_ serviceHymn: ServiceHymn) async throws -> ServiceHymn {
        logger.info("Creating new service hymn for service: \(serviceHymn.serviceId), hymn: \(serviceHymn.hymnId)")
        
        // Validate service hymn data
        try await validateServiceHymn(serviceHymn)
        
        // Check for duplicates
        if try await isHymnInService(hymnId: serviceHymn.hymnId, serviceId: serviceHymn.serviceId) {
            logger.warning("Attempted to create duplicate service hymn")
            throw RepositoryError.duplicateEntity("Hymn is already in this service")
        }
        
        do {
            try await dataManager.insert(serviceHymn)
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceHymn.serviceId)
            
            logger.info("Successfully created service hymn: \(serviceHymn.id)")
            return serviceHymn
        } catch {
            logger.error("Failed to create service hymn: \(error.localizedDescription)")
            throw DataLayerError.insertFailed(error)
        }
    }
    
    func updateServiceHymn(_ serviceHymn: ServiceHymn) async throws -> ServiceHymn {
        logger.info("Updating service hymn: \(serviceHymn.id)")
        
        // Validate service hymn data
        try await validateServiceHymn(serviceHymn)
        
        do {
            try await dataManager.save()
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceHymn.serviceId)
            
            logger.info("Successfully updated service hymn: \(serviceHymn.id)")
            return serviceHymn
        } catch {
            logger.error("Failed to update service hymn: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func deleteServiceHymn(_ serviceHymn: ServiceHymn) async throws {
        logger.info("Deleting service hymn: \(serviceHymn.id)")
        
        let serviceId = serviceHymn.serviceId
        let removedOrder = serviceHymn.order
        
        do {
            try await dataManager.performTransaction {
                // Delete the service hymn
                try await dataManager.delete(serviceHymn)
                
                // Reorder remaining hymns
                try await reorderAfterDeletion(serviceId: serviceId, removedOrder: removedOrder)
            }
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully deleted service hymn: \(serviceHymn.id)")
        } catch {
            logger.error("Failed to delete service hymn: \(error.localizedDescription)")
            throw DataLayerError.deleteFailed(error)
        }
    }
    
    // MARK: - Service-Specific Operations
    
    func getServiceHymns(for serviceId: UUID) async throws -> [ServiceHymn] {
        logger.info("Fetching service hymns for service: \(serviceId)")
        
        // Check cache first
        if let cachedServiceHymns = await cache.getServiceHymns(for: serviceId) {
            logger.info("Service hymns found in cache: \(cachedServiceHymns.count) items")
            return cachedServiceHymns
        }
        
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId
                },
                sortBy: [SortDescriptor(\.order)]
            )
            
            let serviceHymns = try await dataManager.fetch(descriptor)
            
            // Cache the results
            await cache.setServiceHymns(serviceHymns, for: serviceId)
            
            logger.info("Retrieved \(serviceHymns.count) service hymns for service: \(serviceId)")
            return serviceHymns
        } catch {
            logger.error("Failed to fetch service hymns for service: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServiceHymn(serviceId: UUID, hymnId: UUID) async throws -> ServiceHymn? {
        logger.info("Fetching service hymn for service: \(serviceId), hymn: \(hymnId)")
        
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId && serviceHymn.hymnId == hymnId
                }
            )
            
            let serviceHymn = try await dataManager.fetchFirst(descriptor)
            
            if let serviceHymn = serviceHymn {
                logger.info("Service hymn found: \(serviceHymn.id)")
            } else {
                logger.info("Service hymn not found for service: \(serviceId), hymn: \(hymnId)")
            }
            
            return serviceHymn
        } catch {
            logger.error("Failed to fetch service hymn: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func addHymnToService(hymnId: UUID, serviceId: UUID, order: Int?, notes: String?) async throws -> ServiceHymn {
        logger.info("Adding hymn \(hymnId) to service \(serviceId)")
        
        // Check if hymn is already in service
        if try await isHymnInService(hymnId: hymnId, serviceId: serviceId) {
            logger.warning("Attempted to add hymn that's already in service")
            throw RepositoryError.duplicateEntity("Hymn is already in this service")
        }
        
        // Get the next order if not specified
        let finalOrder: Int
        if let order = order {
            finalOrder = order
        } else {
            finalOrder = try await getNextOrder(for: serviceId)
        }
        
        let serviceHymn = ServiceHymn.createForService(
            hymnId: hymnId,
            serviceId: serviceId,
            nextOrder: finalOrder
        )
        
        if let notes = notes {
            serviceHymn.updateNotes(notes)
        }
        
        return try await createServiceHymn(serviceHymn)
    }
    
    func removeHymnFromService(hymnId: UUID, serviceId: UUID) async throws {
        logger.info("Removing hymn \(hymnId) from service \(serviceId)")
        
        guard let serviceHymn = try await getServiceHymn(serviceId: serviceId, hymnId: hymnId) else {
            logger.warning("Attempted to remove hymn that's not in service")
            throw RepositoryError.entityNotFound("Hymn is not in this service")
        }
        
        try await deleteServiceHymn(serviceHymn)
    }
    
    func clearService(_ serviceId: UUID) async throws -> Int {
        logger.info("Clearing all hymns from service: \(serviceId)")
        
        do {
            let deletedCount = try await dataManager.deleteBatch(
                type: ServiceHymn.self,
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId
                }
            )
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully cleared \(deletedCount) hymns from service: \(serviceId)")
            return deletedCount
        } catch {
            logger.error("Failed to clear service hymns: \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    // MARK: - Ordering Operations
    
    func reorderServiceHymns(serviceId: UUID, hymnIds: [UUID]) async throws {
        logger.info("Reordering \(hymnIds.count) hymns in service: \(serviceId)")
        
        do {
            try await dataManager.performTransaction {
                // Get all service hymns for this service
                let serviceHymns = try await getServiceHymns(for: serviceId)
                
                // Create a lookup map
                let serviceHymnMap = Dictionary(grouping: serviceHymns) { $0.hymnId }
                
                // Update order based on the provided hymn IDs
                for (newOrder, hymnId) in hymnIds.enumerated() {
                    if let serviceHymn = serviceHymnMap[hymnId]?.first {
                        serviceHymn.updateOrder(newOrder)
                    }
                }
            }
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully reordered hymns in service: \(serviceId)")
        } catch {
            logger.error("Failed to reorder service hymns: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func moveServiceHymn(serviceId: UUID, hymnId: UUID, to newOrder: Int) async throws {
        logger.info("Moving hymn \(hymnId) to position \(newOrder) in service \(serviceId)")
        
        do {
            try await dataManager.performTransaction {
                let serviceHymns = try await getServiceHymns(for: serviceId)
                
                guard let targetHymn = serviceHymns.first(where: { $0.hymnId == hymnId }) else {
                    throw RepositoryError.entityNotFound("Hymn not found in service")
                }
                
                let oldOrder = targetHymn.order
                
                // Update orders for affected hymns
                if newOrder < oldOrder {
                    // Moving up - shift hymns down
                    for serviceHymn in serviceHymns {
                        if serviceHymn.order >= newOrder && serviceHymn.order < oldOrder {
                            serviceHymn.updateOrder(serviceHymn.order + 1)
                        }
                    }
                } else if newOrder > oldOrder {
                    // Moving down - shift hymns up
                    for serviceHymn in serviceHymns {
                        if serviceHymn.order > oldOrder && serviceHymn.order <= newOrder {
                            serviceHymn.updateOrder(serviceHymn.order - 1)
                        }
                    }
                }
                
                // Update target hymn order
                targetHymn.updateOrder(newOrder)
            }
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully moved hymn \(hymnId) to position \(newOrder)")
        } catch {
            logger.error("Failed to move service hymn: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func getNextOrder(for serviceId: UUID) async throws -> Int {
        logger.info("Getting next order for service: \(serviceId)")
        
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId
                },
                sortBy: [SortDescriptor(\.order, order: .reverse)]
            )
            
            let serviceHymns = try await dataManager.fetch(descriptor)
            let maxOrder = serviceHymns.first?.order ?? -1
            let nextOrder = maxOrder + 1
            
            logger.info("Next order for service \(serviceId): \(nextOrder)")
            return nextOrder
        } catch {
            logger.error("Failed to get next order: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func normalizeOrdering(for serviceId: UUID) async throws {
        logger.info("Normalizing ordering for service: \(serviceId)")
        
        do {
            try await dataManager.performTransaction {
                let serviceHymns = try await getServiceHymns(for: serviceId)
                
                // Sort by current order and reassign sequential numbers
                let sortedHymns = serviceHymns.sorted { $0.order < $1.order }
                
                for (index, serviceHymn) in sortedHymns.enumerated() {
                    serviceHymn.updateOrder(index)
                }
            }
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully normalized ordering for service: \(serviceId)")
        } catch {
            logger.error("Failed to normalize ordering: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    // MARK: - Query Operations
    
    func getServicesContaining(hymnId: UUID) async throws -> [WorshipService] {
        logger.info("Fetching services containing hymn: \(hymnId)")
        
        do {
            // Get service IDs that contain this hymn
            let serviceHymnDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.hymnId == hymnId
                }
            )
            
            let serviceHymns = try await dataManager.fetch(serviceHymnDescriptor)
            let serviceIds = Array(Set(serviceHymns.map { $0.serviceId }))
            
            // Fetch the actual services
            let serviceDescriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    serviceIds.contains(service.id)
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let services = try await dataManager.fetch(serviceDescriptor)
            logger.info("Found \(services.count) services containing hymn: \(hymnId)")
            return services
        } catch {
            logger.error("Failed to fetch services containing hymn: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func isHymnInService(hymnId: UUID, serviceId: UUID) async throws -> Bool {
        do {
            let exists = try await dataManager.exists(
                for: ServiceHymn.self,
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId && serviceHymn.hymnId == hymnId
                }
            )
            
            logger.info("Hymn \(hymnId) in service \(serviceId): \(exists)")
            return exists
        } catch {
            logger.error("Failed to check hymn in service: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnCount(in serviceId: UUID) async throws -> Int {
        do {
            let count = try await dataManager.count(
                for: ServiceHymn.self,
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId
                }
            )
            
            logger.info("Hymn count in service \(serviceId): \(count)")
            return count
        } catch {
            logger.error("Failed to get hymn count in service: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServiceCount(for hymnId: UUID) async throws -> Int {
        do {
            let count = try await dataManager.count(
                for: ServiceHymn.self,
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.hymnId == hymnId
                }
            )
            
            logger.info("Service count for hymn \(hymnId): \(count)")
            return count
        } catch {
            logger.error("Failed to get service count for hymn: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Bulk Operations
    
    func addHymnsToService(hymnIds: [UUID], serviceId: UUID, startingOrder: Int?) async throws -> [ServiceHymn] {
        logger.info("Adding \(hymnIds.count) hymns to service: \(serviceId)")
        
        var result: [ServiceHymn] = []
        let baseOrder: Int
        if let startingOrder = startingOrder {
            baseOrder = startingOrder
        } else {
            baseOrder = try await getNextOrder(for: serviceId)
        }
        
        do {
            try await dataManager.performTransaction {
                for (index, hymnId) in hymnIds.enumerated() {
                    // Check if hymn is already in service
                    if try await isHymnInService(hymnId: hymnId, serviceId: serviceId) {
                        logger.warning("Skipping hymn \(hymnId) - already in service")
                        continue
                    }
                    
                    let serviceHymn = ServiceHymn.createForService(
                        hymnId: hymnId,
                        serviceId: serviceId,
                        nextOrder: baseOrder + index
                    )
                    
                    try await dataManager.insert(serviceHymn)
                    result.append(serviceHymn)
                }
            }
            
            // Clear cache for this service
            await cache.clearServiceHymns(for: serviceId)
            
            logger.info("Successfully added \(result.count) hymns to service: \(serviceId)")
            return result
        } catch {
            logger.error("Failed to add hymns to service: \(error.localizedDescription)")
            throw DataLayerError.batchInsertFailed(error)
        }
    }
    
    func removeHymnsFromService(hymnIds: [UUID], serviceId: UUID) async throws -> Int {
        logger.info("Removing \(hymnIds.count) hymns from service: \(serviceId)")
        
        do {
            let deletedCount = try await dataManager.deleteBatch(
                type: ServiceHymn.self,
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId && hymnIds.contains(serviceHymn.hymnId)
                }
            )
            
            // Normalize ordering after batch deletion
            try await normalizeOrdering(for: serviceId)
            
            logger.info("Successfully removed \(deletedCount) hymns from service: \(serviceId)")
            return deletedCount
        } catch {
            logger.error("Failed to remove hymns from service: \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    func copyServiceHymns(from sourceServiceId: UUID, to targetServiceId: UUID, preserveOrder: Bool) async throws -> [ServiceHymn] {
        logger.info("Copying hymns from service \(sourceServiceId) to service \(targetServiceId)")
        
        do {
            let sourceServiceHymns = try await getServiceHymns(for: sourceServiceId)
            var result: [ServiceHymn] = []
            
            let baseOrder = preserveOrder ? 0 : (try await getNextOrder(for: targetServiceId))
            
            try await dataManager.performTransaction {
                for (index, sourceServiceHymn) in sourceServiceHymns.enumerated() {
                    // Check if hymn is already in target service
                    if try await isHymnInService(hymnId: sourceServiceHymn.hymnId, serviceId: targetServiceId) {
                        logger.warning("Skipping hymn \(sourceServiceHymn.hymnId) - already in target service")
                        continue
                    }
                    
                    let newOrder = preserveOrder ? sourceServiceHymn.order : (baseOrder + index)
                    
                    let newServiceHymn = ServiceHymn(
                        hymnId: sourceServiceHymn.hymnId,
                        serviceId: targetServiceId,
                        order: newOrder,
                        notes: sourceServiceHymn.notes
                    )
                    
                    try await dataManager.insert(newServiceHymn)
                    result.append(newServiceHymn)
                }
            }
            
            // Clear cache for target service
            await cache.clearServiceHymns(for: targetServiceId)
            
            logger.info("Successfully copied \(result.count) hymns to service: \(targetServiceId)")
            return result
        } catch {
            logger.error("Failed to copy service hymns: \(error.localizedDescription)")
            throw DataLayerError.batchInsertFailed(error)
        }
    }
    
    func moveServiceHymns(hymnIds: [UUID], from sourceServiceId: UUID, to targetServiceId: UUID) async throws -> [ServiceHymn] {
        logger.info("Moving \(hymnIds.count) hymns from service \(sourceServiceId) to service \(targetServiceId)")
        
        do {
            var result: [ServiceHymn] = []
            let baseOrder = try await getNextOrder(for: targetServiceId)
            
            try await dataManager.performTransaction {
                // Get source service hymns to move
                let sourceServiceHymns = try await getServiceHymns(for: sourceServiceId)
                let hymnsToMove = sourceServiceHymns.filter { hymnIds.contains($0.hymnId) }
                
                for (index, sourceServiceHymn) in hymnsToMove.enumerated() {
                    // Check if hymn is already in target service
                    if try await isHymnInService(hymnId: sourceServiceHymn.hymnId, serviceId: targetServiceId) {
                        logger.warning("Skipping hymn \(sourceServiceHymn.hymnId) - already in target service")
                        continue
                    }
                    
                    // Create new service hymn in target service
                    let newServiceHymn = ServiceHymn(
                        hymnId: sourceServiceHymn.hymnId,
                        serviceId: targetServiceId,
                        order: baseOrder + index,
                        notes: sourceServiceHymn.notes
                    )
                    
                    try await dataManager.insert(newServiceHymn)
                    result.append(newServiceHymn)
                    
                    // Delete from source service
                    try await dataManager.delete(sourceServiceHymn)
                }
                
                // Normalize ordering in source service
                try await normalizeOrdering(for: sourceServiceId)
            }
            
            // Clear cache for both services
            await cache.clearServiceHymns(for: sourceServiceId)
            await cache.clearServiceHymns(for: targetServiceId)
            
            logger.info("Successfully moved \(result.count) hymns to service: \(targetServiceId)")
            return result
        } catch {
            logger.error("Failed to move service hymns: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    // MARK: - Statistics and Analytics
    
    func getServiceHymnCount() async throws -> Int {
        do {
            let count = try await dataManager.count(for: ServiceHymn.self)
            logger.info("Total service hymn count: \(count)")
            return count
        } catch {
            logger.error("Failed to get service hymn count: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getMostUsedHymns(limit: Int?) async throws -> [(hymn: Hymn, useCount: Int)] {
        logger.info("Fetching most used hymns, limit: \(limit?.description ?? "none")")
        
        do {
            // Get all service hymns
            let allServiceHymns = try await dataManager.fetchAll(ServiceHymn.self)
            
            // Count usage by hymn ID
            var usageCount: [UUID: Int] = [:]
            for serviceHymn in allServiceHymns {
                usageCount[serviceHymn.hymnId, default: 0] += 1
            }
            
            // Sort by usage count and apply limit
            let sortedUsage = usageCount.sorted { $0.value > $1.value }
            let limitedUsage = limit != nil ? Array(sortedUsage.prefix(limit!)) : sortedUsage
            
            // Fetch hymn details
            let hymnIds = limitedUsage.map { $0.key }
            let hymnDescriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymnIds.contains(hymn.id)
                }
            )
            
            let hymns = try await dataManager.fetch(hymnDescriptor)
            let hymnMap = Dictionary(uniqueKeysWithValues: hymns.map { ($0.id, $0) })
            
            // Build result maintaining usage order
            var result: [(hymn: Hymn, useCount: Int)] = []
            for (hymnId, count) in limitedUsage {
                if let hymn = hymnMap[hymnId] {
                    result.append((hymn: hymn, useCount: count))
                }
            }
            
            logger.info("Found \(result.count) most used hymns")
            return result
        } catch {
            logger.error("Failed to get most used hymns: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getAverageHymnCountPerService() async throws -> Double {
        do {
            let serviceHymnCount = try await getServiceHymnCount()
            let serviceCount = try await dataManager.count(for: WorshipService.self)
            
            guard serviceCount > 0 else {
                return 0.0
            }
            
            let average = Double(serviceHymnCount) / Double(serviceCount)
            logger.info("Average hymn count per service: \(average)")
            return average
        } catch {
            logger.error("Failed to get average hymn count per service: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getEmptyServices() async throws -> [WorshipService] {
        logger.info("Fetching empty services")
        
        do {
            // Get all service IDs that have hymns
            let serviceHymns = try await dataManager.fetchAll(ServiceHymn.self)
            let servicesWithHymns = Set(serviceHymns.map { $0.serviceId })
            
            // Get all services that are not in the above set
            let allServices = try await dataManager.fetchAll(WorshipService.self)
            let emptyServices = allServices.filter { !servicesWithHymns.contains($0.id) }
            
            logger.info("Found \(emptyServices.count) empty services")
            return emptyServices
        } catch {
            logger.error("Failed to get empty services: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getOrphanedServiceHymns() async throws -> [ServiceHymn] {
        logger.info("Fetching orphaned service hymns")
        
        do {
            let allServiceHymns = try await dataManager.fetchAll(ServiceHymn.self)
            let allServices = try await dataManager.fetchAll(WorshipService.self)
            let allHymns = try await dataManager.fetchAll(Hymn.self)
            
            let serviceIds = Set(allServices.map { $0.id })
            let hymnIds = Set(allHymns.map { $0.id })
            
            let orphanedServiceHymns = allServiceHymns.filter { serviceHymn in
                !serviceIds.contains(serviceHymn.serviceId) || !hymnIds.contains(serviceHymn.hymnId)
            }
            
            logger.info("Found \(orphanedServiceHymns.count) orphaned service hymns")
            return orphanedServiceHymns
        } catch {
            logger.error("Failed to get orphaned service hymns: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Validation Operations
    
    func validateIntegrity() async throws -> [(issue: String, serviceHymnId: UUID)] {
        logger.info("Validating service hymn integrity")
        
        do {
            var issues: [(issue: String, serviceHymnId: UUID)] = []
            
            let orphanedServiceHymns = try await getOrphanedServiceHymns()
            for serviceHymn in orphanedServiceHymns {
                issues.append((issue: "Orphaned service hymn", serviceHymnId: serviceHymn.id))
            }
            
            // Check for ordering issues
            let allServices = try await dataManager.fetchAll(WorshipService.self)
            for service in allServices {
                let serviceHymns = try await getServiceHymns(for: service.id)
                
                for (expectedOrder, serviceHymn) in serviceHymns.enumerated() {
                    if serviceHymn.order != expectedOrder {
                        issues.append((issue: "Incorrect order", serviceHymnId: serviceHymn.id))
                    }
                }
            }
            
            logger.info("Found \(issues.count) integrity issues")
            return issues
        } catch {
            logger.error("Failed to validate integrity: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func fixAllOrderingIssues() async throws -> Int {
        logger.info("Fixing all ordering issues")
        
        do {
            let allServices = try await dataManager.fetchAll(WorshipService.self)
            var fixedCount = 0
            
            for service in allServices {
                let serviceHymns = try await getServiceHymns(for: service.id)
                
                // Check if reordering is needed
                var needsReordering = false
                for (expectedOrder, serviceHymn) in serviceHymns.enumerated() {
                    if serviceHymn.order != expectedOrder {
                        needsReordering = true
                        break
                    }
                }
                
                if needsReordering {
                    try await normalizeOrdering(for: service.id)
                    fixedCount += 1
                }
            }
            
            logger.info("Fixed ordering issues in \(fixedCount) services")
            return fixedCount
        } catch {
            logger.error("Failed to fix ordering issues: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func cleanupOrphanedServiceHymns() async throws -> Int {
        logger.info("Cleaning up orphaned service hymns")
        
        do {
            let orphanedServiceHymns = try await getOrphanedServiceHymns()
            
            for serviceHymn in orphanedServiceHymns {
                try await dataManager.delete(serviceHymn)
            }
            
            try await dataManager.save()
            
            // Clear all caches since we may have removed items from multiple services
            await cache.clearAll()
            
            logger.info("Cleaned up \(orphanedServiceHymns.count) orphaned service hymns")
            return orphanedServiceHymns.count
        } catch {
            logger.error("Failed to cleanup orphaned service hymns: \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func validateServiceHymn(_ serviceHymn: ServiceHymn) async throws {
        // Validate that the service exists
        let serviceExists = try await dataManager.exists(
            for: WorshipService.self,
            predicate: #Predicate<WorshipService> { service in
                service.id == serviceHymn.serviceId
            }
        )
        
        guard serviceExists else {
            throw BusinessLogicError.invalidInput("Referenced service does not exist")
        }
        
        // Validate that the hymn exists
        let hymnExists = try await dataManager.exists(
            for: Hymn.self,
            predicate: #Predicate<Hymn> { hymn in
                hymn.id == serviceHymn.hymnId
            }
        )
        
        guard hymnExists else {
            throw BusinessLogicError.invalidInput("Referenced hymn does not exist")
        }
        
        // Validate order is not negative
        if serviceHymn.order < 0 {
            throw BusinessLogicError.invalidInput("Service hymn order cannot be negative")
        }
        
        // Validate notes length if present
        if let notes = serviceHymn.notes, notes.count > 1000 {
            throw BusinessLogicError.invalidInput("Service hymn notes cannot exceed 1,000 characters")
        }
    }
    
    private func reorderAfterDeletion(serviceId: UUID, removedOrder: Int) async throws {
        let descriptor = FetchDescriptor<ServiceHymn>(
            predicate: #Predicate<ServiceHymn> { serviceHymn in
                serviceHymn.serviceId == serviceId && serviceHymn.order > removedOrder
            }
        )
        
        let hymnsToReorder = try await dataManager.fetch(descriptor)
        for serviceHymn in hymnsToReorder {
            serviceHymn.updateOrder(serviceHymn.order - 1)
        }
    }
}

// MARK: - ServiceHymn Cache

/// Thread-safe cache for service hymn data
actor ServiceHymnCache {
    
    // MARK: - Properties
    
    private var serviceHymnCache: [UUID: [ServiceHymn]] = [:]
    private var accessTimes: [UUID: Date] = [:]
    private let maxCacheSize = 100 // Number of services to cache
    private let cacheExpirationTime: TimeInterval = 180 // 3 minutes
    
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ServiceHymnCache")
    
    // MARK: - Cache Operations
    
    func getServiceHymns(for serviceId: UUID) -> [ServiceHymn]? {
        // Check if cache entry exists and is not expired
        if let accessTime = accessTimes[serviceId],
           Date().timeIntervalSince(accessTime) > cacheExpirationTime {
            // Entry is expired, remove it
            serviceHymnCache.removeValue(forKey: serviceId)
            accessTimes.removeValue(forKey: serviceId)
            return nil
        }
        
        if let serviceHymns = serviceHymnCache[serviceId] {
            // Update access time
            accessTimes[serviceId] = Date()
            return serviceHymns
        }
        
        return nil
    }
    
    func setServiceHymns(_ serviceHymns: [ServiceHymn], for serviceId: UUID) {
        // Remove old entries if cache is too large
        if serviceHymnCache.count >= maxCacheSize {
            evictOldestEntries()
        }
        
        serviceHymnCache[serviceId] = serviceHymns
        accessTimes[serviceId] = Date()
    }
    
    func clearServiceHymns(for serviceId: UUID) {
        serviceHymnCache.removeValue(forKey: serviceId)
        accessTimes.removeValue(forKey: serviceId)
    }
    
    func clearAll() {
        serviceHymnCache.removeAll()
        accessTimes.removeAll()
        logger.info("ServiceHymn cache cleared")
    }
    
    func getCacheStats() -> (count: Int, size: Int) {
        return (count: serviceHymnCache.count, size: maxCacheSize)
    }
    
    // MARK: - Private Methods
    
    private func evictOldestEntries() {
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
        let toEvict = Array(sortedByAccess.prefix(maxCacheSize / 4)) // Evict 25% of cache
        
        for (serviceId, _) in toEvict {
            serviceHymnCache.removeValue(forKey: serviceId)
            accessTimes.removeValue(forKey: serviceId)
        }
        
        logger.info("Evicted \(toEvict.count) entries from service hymn cache")
    }
}