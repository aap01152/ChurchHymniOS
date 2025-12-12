//
//  RepositoryFactory.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation
import SwiftData
import OSLog
import SwiftUI

/// Factory for creating repository instances with dependency injection
@DataActor
final class RepositoryFactory: RepositoryFactoryProtocol {
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let cacheManager: CacheManager
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "RepositoryFactory")
    
    // Singleton repositories (created once and reused)
    private var _hymnRepository: HymnRepository?
    private var _serviceRepository: ServiceRepository?
    private var _serviceHymnRepository: ServiceHymnRepository?
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager, cacheManager: CacheManager = CacheManager()) {
        self.dataManager = dataManager
        self.cacheManager = cacheManager
        logger.info("RepositoryFactory initialized")
    }
    
    // MARK: - RepositoryFactoryProtocol
    
    func createHymnRepository() async throws -> HymnRepositoryProtocol {
        if let existingRepository = _hymnRepository {
            logger.info("Returning existing HymnRepository instance")
            return existingRepository
        }
        
        logger.info("Creating new HymnRepository instance")
        let hymnCache = cacheManager.getHymnCache()
        let repository = HymnRepository(dataManager: dataManager, cache: hymnCache)
        
        // Perform health check
        let isHealthy = try await repository.healthCheck()
        guard isHealthy else {
            logger.error("HymnRepository health check failed")
            throw RepositoryError.repositoryUnavailable
        }
        
        _hymnRepository = repository
        logger.info("HymnRepository created and health check passed")
        return repository
    }
    
    func createServiceRepository() async throws -> ServiceRepositoryProtocol {
        if let existingRepository = _serviceRepository {
            logger.info("Returning existing ServiceRepository instance")
            return existingRepository
        }
        
        logger.info("Creating new ServiceRepository instance")
        let serviceCache = cacheManager.getServiceCache()
        let repository = ServiceRepository(dataManager: dataManager, cache: serviceCache)
        
        // Perform health check
        let isHealthy = try await repository.healthCheck()
        guard isHealthy else {
            logger.error("ServiceRepository health check failed")
            throw RepositoryError.repositoryUnavailable
        }
        
        _serviceRepository = repository
        logger.info("ServiceRepository created and health check passed")
        return repository
    }
    
    func createServiceHymnRepository() async throws -> ServiceHymnRepositoryProtocol {
        if let existingRepository = _serviceHymnRepository {
            logger.info("Returning existing ServiceHymnRepository instance")
            return existingRepository
        }
        
        logger.info("Creating new ServiceHymnRepository instance")
        let serviceHymnCache = cacheManager.getServiceHymnCache()
        let repository = ServiceHymnRepository(dataManager: dataManager, cache: serviceHymnCache)
        
        // Perform health check
        let isHealthy = try await repository.healthCheck()
        guard isHealthy else {
            logger.error("ServiceHymnRepository health check failed")
            throw RepositoryError.repositoryUnavailable
        }
        
        _serviceHymnRepository = repository
        logger.info("ServiceHymnRepository created and health check passed")
        return repository
    }
    
    // MARK: - Factory Management
    
    /// Clear all cached repository instances (forces recreation on next access)
    func clearRepositoryCache() async {
        logger.info("Clearing repository cache")
        _hymnRepository = nil
        _serviceRepository = nil
        _serviceHymnRepository = nil
    }
    
    /// Perform health check on all created repositories
    func performHealthChecks() async throws -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        if let hymnRepo = _hymnRepository {
            do {
                results["HymnRepository"] = try await hymnRepo.healthCheck()
            } catch {
                results["HymnRepository"] = false
            }
        }
        
        if let serviceRepo = _serviceRepository {
            do {
                results["ServiceRepository"] = try await serviceRepo.healthCheck()
            } catch {
                results["ServiceRepository"] = false
            }
        }
        
        if let serviceHymnRepo = _serviceHymnRepository {
            do {
                results["ServiceHymnRepository"] = try await serviceHymnRepo.healthCheck()
            } catch {
                results["ServiceHymnRepository"] = false
            }
        }
        
        logger.info("Health check results: \(results)")
        return results
    }
    
    /// Clear all caches across all repositories
    func clearAllCaches() {
        logger.info("Clearing all repository caches")
        
        Task {
            if let hymnRepo = _hymnRepository {
                try await hymnRepo.clearCache()
            }
            
            if let serviceRepo = _serviceRepository {
                try await serviceRepo.clearCache()
            }
            
            if let serviceHymnRepo = _serviceHymnRepository {
                try await serviceHymnRepo.clearCache()
            }
        }
        
        cacheManager.clearAllCaches()
        logger.info("All repository caches cleared")
    }
    
    /// Get repository creation statistics
    func getRepositoryStats() -> RepositoryStats {
        return RepositoryStats(
            hymnRepositoryCreated: _hymnRepository != nil,
            serviceRepositoryCreated: _serviceRepository != nil,
            serviceHymnRepositoryCreated: _serviceHymnRepository != nil,
            lastAccessTime: Date()
        )
    }
    
    /// Get access to the underlying data manager
    func getDataManager() async -> SwiftDataManager {
        return dataManager
    }
}

// MARK: - Cache Manager

/// Manages all cache instances for repositories
final class CacheManager: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var _hymnCache: HymnCache?
    private var _serviceCache: ServiceCache?
    private var _serviceHymnCache: ServiceHymnCache?
    
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "CacheManager")
    
    // MARK: - Cache Accessors
    
    func getHymnCache() -> HymnCache {
        if let existingCache = _hymnCache {
            return existingCache
        }
        
        logger.info("Creating new HymnCache instance")
        let cache = HymnCache()
        _hymnCache = cache
        return cache
    }
    
    func getServiceCache() -> ServiceCache {
        if let existingCache = _serviceCache {
            return existingCache
        }
        
        logger.info("Creating new ServiceCache instance")
        let cache = ServiceCache()
        _serviceCache = cache
        return cache
    }
    
    func getServiceHymnCache() -> ServiceHymnCache {
        if let existingCache = _serviceHymnCache {
            return existingCache
        }
        
        logger.info("Creating new ServiceHymnCache instance")
        let cache = ServiceHymnCache()
        _serviceHymnCache = cache
        return cache
    }
    
    // MARK: - Cache Management
    
    func clearAllCaches() {
        logger.info("Clearing all caches")
        
        if let hymnCache = _hymnCache {
            Task { await hymnCache.clearAll() }
        }
        
        if let serviceCache = _serviceCache {
            Task { await serviceCache.clearAll() }
        }
        
        if let serviceHymnCache = _serviceHymnCache {
            Task { await serviceHymnCache.clearAll() }
        }
        
        logger.info("All caches cleared")
    }
    
    func getCacheStats() async -> CacheStats {
        var stats = CacheStats()
        
        if let hymnCache = _hymnCache {
            let hymnStats = await hymnCache.getCacheStats()
            stats.hymnCacheCount = hymnStats.count
            stats.hymnCacheSize = hymnStats.size
        }
        
        if let serviceCache = _serviceCache {
            let serviceStats = await serviceCache.getCacheStats()
            stats.serviceCacheCount = serviceStats.count
            stats.serviceCacheSize = serviceStats.size
            stats.hasActiveServiceCached = serviceStats.hasActiveService
        }
        
        if let serviceHymnCache = _serviceHymnCache {
            let serviceHymnStats = await serviceHymnCache.getCacheStats()
            stats.serviceHymnCacheCount = serviceHymnStats.count
            stats.serviceHymnCacheSize = serviceHymnStats.size
        }
        
        return stats
    }
    
    /// Reset all cache instances (forces recreation)
    func resetCaches() {
        logger.info("Resetting all cache instances")
        _hymnCache = nil
        _serviceCache = nil
        _serviceHymnCache = nil
    }
}

// MARK: - Repository Manager

/// Manages all repositories and provides coordinated access
@MainActor
final class RepositoryManager: RepositoryManagerProtocol, ObservableObject {
    
    // MARK: - Properties
    
    private let factory: RepositoryFactory
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "RepositoryManager")
    
    // Cached repository references
    private var _hymnRepository: HymnRepositoryProtocol?
    private var _serviceRepository: ServiceRepositoryProtocol?
    private var _serviceHymnRepository: ServiceHymnRepositoryProtocol?
    
    // MARK: - Initialization
    
    init(factory: RepositoryFactory) {
        self.factory = factory
        logger.info("RepositoryManager initialized")
    }
    
    static func create(dataManager: SwiftDataManager) async -> RepositoryManager {
        let cacheManager = CacheManager()
        let factory = await RepositoryFactory(dataManager: dataManager, cacheManager: cacheManager)
        return RepositoryManager(factory: factory)
    }
    
    // MARK: - RepositoryManagerProtocol
    
    var hymnRepository: HymnRepositoryProtocol {
        get async throws {
            if let repository = _hymnRepository {
                return repository
            }
            
            let repository = try await factory.createHymnRepository()
            _hymnRepository = repository
            return repository
        }
    }
    
    var serviceRepository: ServiceRepositoryProtocol {
        get async throws {
            if let repository = _serviceRepository {
                return repository
            }
            
            let repository = try await factory.createServiceRepository()
            _serviceRepository = repository
            return repository
        }
    }
    
    var serviceHymnRepository: ServiceHymnRepositoryProtocol {
        get async throws {
            if let repository = _serviceHymnRepository {
                return repository
            }
            
            let repository = try await factory.createServiceHymnRepository()
            _serviceHymnRepository = repository
            return repository
        }
    }
    
    func performHealthCheck() async throws -> [String: Bool] {
        logger.info("Performing health check on all repositories")
        
        var results: [String: Bool] = [:]
        
        // Check hymn repository
        do {
            let hymnRepo = try await hymnRepository
            results["HymnRepository"] = try await hymnRepo.healthCheck()
        } catch {
            logger.error("HymnRepository health check failed: \(error.localizedDescription)")
            results["HymnRepository"] = false
        }
        
        // Check service repository
        do {
            let serviceRepo = try await serviceRepository
            results["ServiceRepository"] = try await serviceRepo.healthCheck()
        } catch {
            logger.error("ServiceRepository health check failed: \(error.localizedDescription)")
            results["ServiceRepository"] = false
        }
        
        // Check service hymn repository
        do {
            let serviceHymnRepo = try await serviceHymnRepository
            results["ServiceHymnRepository"] = try await serviceHymnRepo.healthCheck()
        } catch {
            logger.error("ServiceHymnRepository health check failed: \(error.localizedDescription)")
            results["ServiceHymnRepository"] = false
        }
        
        logger.info("Health check completed: \(results)")
        return results
    }
    
    func clearAllCaches() async throws {
        logger.info("Clearing all repository caches")
        
        await factory.clearAllCaches()
        
        logger.info("All repository caches cleared")
    }
    
    func shutdown() async throws {
        logger.info("Shutting down RepositoryManager")
        
        // Clear all caches
        try await clearAllCaches()
        
        // Clear repository references
        _hymnRepository = nil
        _serviceRepository = nil
        _serviceHymnRepository = nil
        
        // Clear factory cache
        await factory.clearRepositoryCache()
        
        logger.info("RepositoryManager shutdown completed")
    }
    
    /// Get access to the underlying data manager
    func getDataManager() async -> SwiftDataManager {
        await factory.getDataManager()
    }
    
    // MARK: - Coordinated Operations
    
    /// Create a service with hymns in a single transaction
    func createServiceWithHymns(
        serviceTitle: String,
        serviceDate: Date,
        serviceNotes: String?,
        hymnIds: [UUID]
    ) async throws -> (service: WorshipService, serviceHymns: [ServiceHymn]) {
        logger.info("Creating service with \(hymnIds.count) hymns")
        
        do {
            let serviceRepo = try await serviceRepository
            let serviceHymnRepo = try await serviceHymnRepository
            
            // Create the service
            let newService = WorshipService(
                title: serviceTitle,
                date: serviceDate,
                notes: serviceNotes
            )
            
            let createdService = try await serviceRepo.createService(newService)
            
            // Add hymns to the service
            let serviceHymns = try await serviceHymnRepo.addHymnsToService(
                hymnIds: hymnIds,
                serviceId: createdService.id,
                startingOrder: 0
            )
            
            logger.info("Successfully created service with \(serviceHymns.count) hymns")
            return (service: createdService, serviceHymns: serviceHymns)
        } catch {
            logger.error("Failed to create service with hymns: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete a service and all its hymns
    func deleteServiceWithHymns(_ service: WorshipService) async throws {
        logger.info("Deleting service and all its hymns: \(service.displayTitle)")
        
        do {
            let serviceRepo = try await serviceRepository
            let serviceHymnRepo = try await serviceHymnRepository
            
            // Clear all hymns from the service first
            let deletedHymnCount = try await serviceHymnRepo.clearService(service.id)
            
            // Then delete the service
            try await serviceRepo.deleteService(service)
            
            logger.info("Successfully deleted service and \(deletedHymnCount) hymns")
        } catch {
            logger.error("Failed to delete service with hymns: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get complete service data (service + hymns + hymn details)
    func getCompleteServiceData(serviceId: UUID) async throws -> CompleteServiceData? {
        logger.info("Fetching complete service data for: \(serviceId)")
        
        do {
            let serviceRepo = try await serviceRepository
            let serviceHymnRepo = try await serviceHymnRepository
            let hymnRepo = try await hymnRepository
            
            // Get the service
            guard let service = try await serviceRepo.getService(by: serviceId) else {
                logger.info("Service not found: \(serviceId)")
                return nil
            }
            
            // Get service hymns
            let serviceHymns = try await serviceHymnRepo.getServiceHymns(for: serviceId)
            
            // Get hymn details
            let hymnIds = serviceHymns.map { $0.hymnId }
            let hymns = try await hymnRepo.getHymns(by: hymnIds)
            
            // Create hymn lookup map
            let hymnMap = Dictionary(uniqueKeysWithValues: hymns.map { hymn in (hymn.id, hymn) })
            
            // Build ordered hymn list
            let orderedHymns: [ServiceHymnData] = serviceHymns.compactMap { serviceHymn in
                guard let hymn = hymnMap[serviceHymn.hymnId] else {
                    logger.warning("Hymn not found for service hymn: \(serviceHymn.hymnId)")
                    return nil
                }
                return ServiceHymnData(serviceHymn: serviceHymn, hymn: hymn)
            }
            
            let completeData = CompleteServiceData(
                service: service,
                hymns: orderedHymns
            )
            
            logger.info("Retrieved complete service data: \(orderedHymns.count) hymns")
            return completeData
        } catch {
            logger.error("Failed to get complete service data: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Data Transfer Objects

/// Statistics about repository creation and usage
struct RepositoryStats: Sendable {
    let hymnRepositoryCreated: Bool
    let serviceRepositoryCreated: Bool
    let serviceHymnRepositoryCreated: Bool
    let lastAccessTime: Date
}

/// Statistics about cache usage
struct CacheStats: Sendable {
    var hymnCacheCount: Int = 0
    var hymnCacheSize: Int = 0
    var serviceCacheCount: Int = 0
    var serviceCacheSize: Int = 0
    var hasActiveServiceCached: Bool = false
    var serviceHymnCacheCount: Int = 0
    var serviceHymnCacheSize: Int = 0
}

/// Complete service data with hymn details
struct CompleteServiceData: Sendable {
    let service: WorshipService
    let hymns: [ServiceHymnData]
}

/// Service hymn with full hymn details
struct ServiceHymnData: Sendable {
    let serviceHymn: ServiceHymn
    let hymn: Hymn
    
    var order: Int { serviceHymn.order }
    var notes: String? { serviceHymn.notes }
    var title: String { hymn.title }
    var lyrics: String? { hymn.lyrics }
}

// MARK: - Factory Extension for Convenience

extension RepositoryFactory {
    
    /// Create a complete repository manager with all dependencies
    static func createCompleteManager(dataManager: SwiftDataManager) async throws -> RepositoryManager {
        return await RepositoryManager.create(dataManager: dataManager)
    }
}

// MARK: - Environment Extension

extension View {
    /// Inject repository manager into the environment
    func repositoryManager(_ manager: RepositoryManager) -> some View {
        self.environmentObject(manager)
    }
}
