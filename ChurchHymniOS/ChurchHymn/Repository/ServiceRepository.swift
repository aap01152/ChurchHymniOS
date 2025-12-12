//
//  ServiceRepository.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation
import SwiftData
import OSLog

/// Thread-safe repository for worship service data access operations
@DataActor
final class ServiceRepository: ServiceRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let cache: ServiceCache
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ServiceRepository")
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager, cache: ServiceCache = ServiceCache()) {
        self.dataManager = dataManager
        self.cache = cache
        logger.info("ServiceRepository initialized")
    }
    
    // MARK: - BaseRepositoryProtocol
    
    func healthCheck() async throws -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Test basic operations
            let count = try await dataManager.count(for: WorshipService.self)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.info("Health check passed: \(count) services, response time: \(duration, format: .fixed(precision: 3))s")
            return true
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            throw RepositoryError.repositoryUnavailable
        }
    }
    
    func clearCache() async throws {
        await cache.clearAll()
        logger.info("Service cache cleared")
    }
    
    // MARK: - Basic CRUD Operations
    
    func getAllServices() async throws -> [WorshipService] {
        logger.info("Fetching all services")
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let services = try await dataManager.fetch(descriptor)
            
            // Cache the results
            for service in services {
                await cache.setService(service)
            }
            
            logger.info("Retrieved \(services.count) services")
            return services
        } catch {
            logger.error("Failed to fetch all services: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServices(sortBy: [SortDescriptor<WorshipService>], limit: Int?, offset: Int?) async throws -> [WorshipService] {
        logger.info("Fetching services with custom sorting, limit: \(limit?.description ?? "none"), offset: \(offset?.description ?? "none")")
        
        do {
            var descriptor = FetchDescriptor<WorshipService>(sortBy: sortBy)
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            if let offset = offset {
                descriptor.fetchOffset = offset
            }
            
            let services = try await dataManager.fetch(descriptor)
            
            // Cache the results
            for service in services {
                await cache.setService(service)
            }
            
            logger.info("Retrieved \(services.count) services with custom parameters")
            return services
        } catch {
            logger.error("Failed to fetch services with parameters: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getService(by id: UUID) async throws -> WorshipService? {
        logger.info("Fetching service by ID: \(id)")
        
        // Check cache first
        if let cachedService = await cache.getService(by: id) {
            logger.info("Service found in cache: \(cachedService.displayTitle)")
            return cachedService
        }
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.id == id
                }
            )
            
            let service = try await dataManager.fetchFirst(descriptor)
            
            // Cache the result
            if let service = service {
                await cache.setService(service)
                logger.info("Service found and cached: \(service.displayTitle)")
            } else {
                logger.info("Service not found with ID: \(id)")
            }
            
            return service
        } catch {
            logger.error("Failed to fetch service by ID: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServices(by ids: [UUID]) async throws -> [WorshipService] {
        logger.info("Fetching \(ids.count) services by IDs")
        
        var result: [WorshipService] = []
        var uncachedIds: [UUID] = []
        
        // Check cache for each ID
        for id in ids {
            if let cachedService = await cache.getService(by: id) {
                result.append(cachedService)
            } else {
                uncachedIds.append(id)
            }
        }
        
        // Fetch uncached services from database
        if !uncachedIds.isEmpty {
            do {
                let descriptor = FetchDescriptor<WorshipService>(
                    predicate: #Predicate<WorshipService> { service in
                        uncachedIds.contains(service.id)
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                
                let uncachedServices = try await dataManager.fetch(descriptor)
                result.append(contentsOf: uncachedServices)
                
                // Cache the newly fetched services
                for service in uncachedServices {
                    await cache.setService(service)
                }
            } catch {
                logger.error("Failed to fetch services by IDs: \(error.localizedDescription)")
                throw DataLayerError.fetchFailed(error)
            }
        }
        
        logger.info("Retrieved \(result.count) services by IDs (\(result.count - uncachedIds.count) from cache)")
        return result.sorted { $0.date > $1.date }
    }
    
    func createService(_ service: WorshipService) async throws -> WorshipService {
        logger.info("Creating new service: \(service.displayTitle)")
        
        // Validate service data
        try validateService(service)
        
        do {
            try await dataManager.insert(service)
            
            // Cache the new service
            await cache.setService(service)
            
            // Clear active service cache since state might have changed
            await cache.clearActiveService()
            
            logger.info("Successfully created service: \(service.displayTitle)")
            return service
        } catch {
            logger.error("Failed to create service: \(error.localizedDescription)")
            throw DataLayerError.insertFailed(error)
        }
    }
    
    func updateService(_ service: WorshipService) async throws -> WorshipService {
        logger.info("Updating service: \(service.displayTitle)")
        
        // Validate service data
        try validateService(service)
        
        do {
            // Update timestamp
            service.updateTimestamp()
            
            try await dataManager.save()
            
            // Update cache
            await cache.setService(service)
            
            // Clear active service cache if this service is active
            if service.isActive {
                await cache.clearActiveService()
            }
            
            logger.info("Successfully updated service: \(service.displayTitle)")
            return service
        } catch {
            logger.error("Failed to update service: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func deleteService(_ service: WorshipService) async throws {
        logger.info("Deleting service: \(service.displayTitle)")
        
        do {
            try await dataManager.delete(service)
            
            // Remove from cache
            await cache.removeService(by: service.id)
            
            // Clear active service cache if this was the active service
            if service.isActive {
                await cache.clearActiveService()
            }
            
            logger.info("Successfully deleted service: \(service.displayTitle)")
        } catch {
            logger.error("Failed to delete service: \(error.localizedDescription)")
            throw DataLayerError.deleteFailed(error)
        }
    }
    
    func deleteServices(ids: [UUID]) async throws -> Int {
        logger.info("Deleting \(ids.count) services")
        
        do {
            let deletedCount = try await dataManager.deleteBatch(
                type: WorshipService.self,
                predicate: #Predicate<WorshipService> { service in
                    ids.contains(service.id)
                }
            )
            
            // Remove from cache
            for id in ids {
                await cache.removeService(by: id)
            }
            
            // Clear active service cache since an active service might have been deleted
            await cache.clearActiveService()
            
            logger.info("Successfully deleted \(deletedCount) services")
            return deletedCount
        } catch {
            logger.error("Failed to delete services: \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    // MARK: - Service State Management
    
    func getActiveService() async throws -> WorshipService? {
        logger.info("Fetching active service")
        
        // Check cache first
        if let cachedActiveService = await cache.getActiveService() {
            logger.info("Active service found in cache: \(cachedActiveService.displayTitle)")
            return cachedActiveService
        }
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.isActive == true
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let activeService = try await dataManager.fetchFirst(descriptor)
            
            // Cache the result
            if let activeService = activeService {
                await cache.setActiveService(activeService)
                await cache.setService(activeService)
                logger.info("Active service found and cached: \(activeService.displayTitle)")
            } else {
                logger.info("No active service found")
            }
            
            return activeService
        } catch {
            logger.error("Failed to fetch active service: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func setActiveService(_ service: WorshipService) async throws {
        logger.info("Setting active service: \(service.displayTitle)")
        
        do {
            try await dataManager.performTransaction {
                // Deactivate all other services first
                let allServicesDescriptor = FetchDescriptor<WorshipService>()
                let allServices = try await dataManager.fetch(allServicesDescriptor)
                
                for existingService in allServices {
                    if existingService.id != service.id {
                        existingService.setActive(false)
                    }
                }
                
                // Activate the target service
                service.setActive(true)
            }
            
            // Update cache
            await cache.setActiveService(service)
            await cache.setService(service)
            
            // Clear cache for all other services to ensure consistency
            await cache.clearAllExcept(service.id)
            
            logger.info("Successfully set active service: \(service.displayTitle)")
        } catch {
            logger.error("Failed to set active service: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func deactivateAllServices() async throws {
        logger.info("Deactivating all services")
        
        do {
            let activeServices = try await getServices(isActive: true)
            
            try await dataManager.performTransaction {
                for service in activeServices {
                    service.setActive(false)
                }
            }
            
            // Clear active service cache
            await cache.clearActiveService()
            
            // Update cache for affected services
            for service in activeServices {
                await cache.setService(service)
            }
            
            logger.info("Successfully deactivated \(activeServices.count) services")
        } catch {
            logger.error("Failed to deactivate all services: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func getServices(isActive: Bool) async throws -> [WorshipService] {
        logger.info("Fetching services with active status: \(isActive)")
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.isActive == isActive
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Found \(services.count) services with active status: \(isActive)")
            return services
        } catch {
            logger.error("Failed to fetch services by active status: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Date-based Operations
    
    func getServicesForDate(_ date: Date) async throws -> [WorshipService] {
        logger.info("Fetching services for date: \(date)")
        
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.date >= startOfDay && service.date < endOfDay
                },
                sortBy: [SortDescriptor(\.date)]
            )
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Found \(services.count) services for date: \(date)")
            return services
        } catch {
            logger.error("Failed to fetch services for date: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServicesBetween(_ startDate: Date, _ endDate: Date) async throws -> [WorshipService] {
        logger.info("Fetching services between \(startDate) and \(endDate)")
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.date >= startDate && service.date <= endDate
                },
                sortBy: [SortDescriptor(\.date)]
            )
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Found \(services.count) services in date range")
            return services
        } catch {
            logger.error("Failed to fetch services by date range: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getTodaysServices() async throws -> [WorshipService] {
        return try await getServicesForDate(Date())
    }
    
    func getThisWeeksServices() async throws -> [WorshipService] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.end else {
            logger.error("Failed to calculate week boundaries")
            throw BusinessLogicError.invalidInput("Unable to calculate week boundaries")
        }
        
        return try await getServicesBetween(startOfWeek, endOfWeek)
    }
    
    func getThisMonthsServices() async throws -> [WorshipService] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start,
              let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end else {
            logger.error("Failed to calculate month boundaries")
            throw BusinessLogicError.invalidInput("Unable to calculate month boundaries")
        }
        
        return try await getServicesBetween(startOfMonth, endOfMonth)
    }
    
    // MARK: - Search and Filter Operations
    
    func searchServices(query: String, limit: Int?) async throws -> [WorshipService] {
        logger.info("Searching services with query: '\(query)', limit: \(limit?.description ?? "none")")
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }
        
        do {
            var descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.title.localizedStandardContains(trimmedQuery) ||
                    (service.notes?.localizedStandardContains(trimmedQuery) ?? false)
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Search returned \(services.count) services")
            return services
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func filterServices(hasNotes: Bool?, isActive: Bool?, dateRange: DateInterval?, limit: Int?) async throws -> [WorshipService] {
        logger.info("Filtering services - hasNotes: \(hasNotes?.description ?? "nil"), isActive: \(isActive?.description ?? "nil"), dateRange: \(dateRange?.description ?? "nil")")
        
        do {
            var descriptor = FetchDescriptor<WorshipService>(
                predicate: buildFilterPredicate(hasNotes: hasNotes, isActive: isActive, dateRange: dateRange),
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Filter returned \(services.count) services")
            return services
        } catch {
            logger.error("Filter failed: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Statistics and Analytics
    
    func getServiceCount() async throws -> Int {
        do {
            let count = try await dataManager.count(for: WorshipService.self)
            logger.info("Total service count: \(count)")
            return count
        } catch {
            logger.error("Failed to get service count: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServiceCount(hasNotes: Bool?, isActive: Bool?, dateRange: DateInterval?) async throws -> Int {
        do {
            let predicate = buildFilterPredicate(hasNotes: hasNotes, isActive: isActive, dateRange: dateRange)
            let count = try await dataManager.count(for: WorshipService.self, predicate: predicate)
            logger.info("Filtered service count: \(count)")
            return count
        } catch {
            logger.error("Failed to get filtered service count: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getServicesCreatedBetween(_ startDate: Date, _ endDate: Date) async throws -> [WorshipService] {
        logger.info("Fetching services created between \(startDate) and \(endDate)")
        
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.createdAt >= startDate && service.createdAt <= endDate
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let services = try await dataManager.fetch(descriptor)
            logger.info("Found \(services.count) services created in date range")
            return services
        } catch {
            logger.error("Failed to fetch services by creation date range: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func serviceExists(for date: Date, excludingId: UUID?) async throws -> Bool {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let predicate: Predicate<WorshipService>
            
            if let excludingId = excludingId {
                predicate = #Predicate<WorshipService> { service in
                    service.date >= startOfDay && service.date < endOfDay && service.id != excludingId
                }
            } else {
                predicate = #Predicate<WorshipService> { service in
                    service.date >= startOfDay && service.date < endOfDay
                }
            }
            
            let exists = try await dataManager.exists(for: WorshipService.self, predicate: predicate)
            logger.info("Service exists check for \(date): \(exists)")
            return exists
        } catch {
            logger.error("Failed to check service existence: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func validateService(_ service: WorshipService) throws {
        let trimmedTitle = service.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            throw BusinessLogicError.invalidInput("Service title cannot be empty")
        }
        
        if trimmedTitle.count > 200 {
            throw BusinessLogicError.invalidInput("Service title cannot exceed 200 characters")
        }
        
        if let notes = service.notes, notes.count > 5000 {
            throw BusinessLogicError.invalidInput("Service notes cannot exceed 5,000 characters")
        }
        
        // Validate date is not too far in the future (e.g., more than 1 year)
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        if service.date > oneYearFromNow {
            throw BusinessLogicError.invalidInput("Service date cannot be more than one year in the future")
        }
    }
    
    private func buildFilterPredicate(hasNotes: Bool?, isActive: Bool?, dateRange: DateInterval?) -> Predicate<WorshipService>? {
        var conditions: [Predicate<WorshipService>] = []
        
        if let hasNotes = hasNotes {
            if hasNotes {
                conditions.append(#Predicate<WorshipService> { service in
                    service.notes != nil && !service.notes!.isEmpty
                })
            } else {
                conditions.append(#Predicate<WorshipService> { service in
                    service.notes == nil || service.notes!.isEmpty
                })
            }
        }
        
        if let isActive = isActive {
            conditions.append(#Predicate<WorshipService> { service in
                service.isActive == isActive
            })
        }
        
        if let dateRange = dateRange {
            conditions.append(#Predicate<WorshipService> { service in
                service.date >= dateRange.start && service.date <= dateRange.end
            })
        }
        
        guard !conditions.isEmpty else { return nil }
        
        // Combine all conditions with AND logic
        return #Predicate<WorshipService> { service in
            conditions.allSatisfy { condition in condition.evaluate(service) }
        }
    }
}

// MARK: - Service Cache

/// Thread-safe cache for service data
actor ServiceCache {
    
    // MARK: - Properties
    
    private var cache: [UUID: WorshipService] = [:]
    private var accessTimes: [UUID: Date] = [:]
    private var activeService: WorshipService?
    private var activeServiceCacheTime: Date?
    
    private let maxCacheSize = 500
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let activeServiceExpirationTime: TimeInterval = 60 // 1 minute
    
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ServiceCache")
    
    // MARK: - Cache Operations
    
    func getService(by id: UUID) -> WorshipService? {
        // Check if cache entry exists and is not expired
        if let accessTime = accessTimes[id],
           Date().timeIntervalSince(accessTime) > cacheExpirationTime {
            // Entry is expired, remove it
            cache.removeValue(forKey: id)
            accessTimes.removeValue(forKey: id)
            return nil
        }
        
        if let service = cache[id] {
            // Update access time
            accessTimes[id] = Date()
            return service
        }
        
        return nil
    }
    
    func setService(_ service: WorshipService) {
        // Remove old entries if cache is too large
        if cache.count >= maxCacheSize {
            evictOldestEntries()
        }
        
        cache[service.id] = service
        accessTimes[service.id] = Date()
        
        // Update active service cache if this is the active service
        if service.isActive {
            activeService = service
            activeServiceCacheTime = Date()
        }
    }
    
    func removeService(by id: UUID) {
        cache.removeValue(forKey: id)
        accessTimes.removeValue(forKey: id)
        
        // Clear active service cache if this was the active service
        if activeService?.id == id {
            activeService = nil
            activeServiceCacheTime = nil
        }
    }
    
    func getActiveService() -> WorshipService? {
        // Check if active service cache is expired
        if let cacheTime = activeServiceCacheTime,
           Date().timeIntervalSince(cacheTime) > activeServiceExpirationTime {
            // Active service cache is expired
            activeService = nil
            activeServiceCacheTime = nil
            return nil
        }
        
        return activeService
    }
    
    func setActiveService(_ service: WorshipService) {
        activeService = service
        activeServiceCacheTime = Date()
        
        // Also cache the service normally
        setService(service)
    }
    
    func clearActiveService() {
        activeService = nil
        activeServiceCacheTime = nil
    }
    
    func clearAll() {
        cache.removeAll()
        accessTimes.removeAll()
        activeService = nil
        activeServiceCacheTime = nil
        logger.info("Service cache cleared")
    }
    
    func clearAllExcept(_ id: UUID) {
        let serviceToKeep = cache[id]
        let accessTimeToKeep = accessTimes[id]
        
        cache.removeAll()
        accessTimes.removeAll()
        
        if let serviceToKeep = serviceToKeep, let accessTimeToKeep = accessTimeToKeep {
            cache[id] = serviceToKeep
            accessTimes[id] = accessTimeToKeep
        }
        
        logger.info("Service cache cleared except for service: \(id)")
    }
    
    func getCacheStats() -> (count: Int, size: Int, hasActiveService: Bool) {
        return (
            count: cache.count,
            size: maxCacheSize,
            hasActiveService: activeService != nil
        )
    }
    
    // MARK: - Private Methods
    
    private func evictOldestEntries() {
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
        let toEvict = Array(sortedByAccess.prefix(maxCacheSize / 4)) // Evict 25% of cache
        
        for (id, _) in toEvict {
            cache.removeValue(forKey: id)
            accessTimes.removeValue(forKey: id)
        }
        
        logger.info("Evicted \(toEvict.count) entries from service cache")
    }
}