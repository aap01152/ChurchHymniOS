import Foundation
import SwiftData
import OSLog
import SwiftUI

/// Factory for creating business logic service instances with dependency injection
@MainActor
final class ServiceFactory: ObservableObject {
    
    // MARK: - Properties
    
    private let repositoryManager: RepositoryManager
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ServiceFactory")
    
    // Singleton service instances (created once and reused)
    private var _hymnService: HymnService?
    private var _serviceService: ServiceService?
    
    // MARK: - Initialization
    
    init(repositoryManager: RepositoryManager) {
        self.repositoryManager = repositoryManager
        logger.info("ServiceFactory initialized")
    }
    
    /// Create a ServiceFactory with all dependencies
    static func create(dataManager: SwiftDataManager) async throws -> ServiceFactory {
        let repositoryManager = await RepositoryManager.create(dataManager: dataManager)
        return ServiceFactory(repositoryManager: repositoryManager)
    }
    
    // MARK: - Service Creation
    
    /// Get or create HymnService instance
    func createHymnService() async throws -> HymnService {
        if let existingService = _hymnService {
            logger.info("Returning existing HymnService instance")
            return existingService
        }
        
        logger.info("Creating new HymnService instance")
        
        do {
            let hymnRepository = try await repositoryManager.hymnRepository
            let service = HymnService(repository: hymnRepository)
            
            _hymnService = service
            logger.info("HymnService created successfully")
            return service
        } catch {
            logger.error("Failed to create HymnService: \(error.localizedDescription)")
            throw ServiceCreationError.failedToCreateHymnService(error)
        }
    }
    
    /// Get or create ServiceService instance
    func createServiceService() async throws -> ServiceService {
        if let existingService = _serviceService {
            logger.info("Returning existing ServiceService instance")
            return existingService
        }
        
        logger.info("Creating new ServiceService instance")
        
        do {
            let serviceRepository = try await repositoryManager.serviceRepository
            let hymnRepository = try await repositoryManager.hymnRepository
            let serviceHymnRepository = try await repositoryManager.serviceHymnRepository
            
            let service = ServiceService(
                serviceRepository: serviceRepository,
                hymnRepository: hymnRepository,
                serviceHymnRepository: serviceHymnRepository
            )
            
            _serviceService = service
            logger.info("ServiceService created successfully")
            return service
        } catch {
            logger.error("Failed to create ServiceService: \(error.localizedDescription)")
            throw ServiceCreationError.failedToCreateServiceService(error)
        }
    }
    
    /// Create HymnOperations instance
    func createHymnOperations() async throws -> HymnOperations {
        logger.info("Creating HymnOperations instance")
        
        do {
            // Get dataManager through the factory's dataManager property
            let dataManager = await repositoryManager.getDataManager()
            let operations = await HymnOperations(context: dataManager.mainContext)
            
            logger.info("HymnOperations created successfully")
            return operations
        } catch {
            logger.error("Failed to create HymnOperations: \(error.localizedDescription)")
            throw ServiceCreationError.repositoryUnavailable("Failed to create HymnOperations")
        }
    }
    
    // MARK: - Service Bundle Creation
    
    /// Create both services together for coordinated initialization
    func createServiceBundle() async throws -> ServiceBundle {
        logger.info("Creating complete service bundle")
        
        do {
            let hymnService = try await createHymnService()
            let serviceService = try await createServiceService()
            
            let bundle = ServiceBundle(
                hymnService: hymnService,
                serviceService: serviceService
            )
            
            logger.info("Service bundle created successfully")
            return bundle
        } catch {
            logger.error("Failed to create service bundle: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Service Management
    
    /// Perform health check on all repositories
    func performHealthCheck() async throws -> [String: Bool] {
        logger.info("Performing health check through repository manager")
        return try await repositoryManager.performHealthCheck()
    }
    
    /// Clear all caches in the repository layer
    func clearAllCaches() async throws {
        logger.info("Clearing all caches through repository manager")
        try await repositoryManager.clearAllCaches()
    }
    
    /// Reset all service instances (forces recreation)
    func resetServices() {
        logger.info("Resetting all service instances")
        _hymnService = nil
        _serviceService = nil
    }
    
    /// Initialize services with data loading
    func initializeServices() async throws {
        logger.info("Initializing services with data loading")
        
        do {
            // Create services
            let hymnService = try await createHymnService()
            let serviceService = try await createServiceService()
            
            // Load initial data
            await hymnService.loadHymns()
            await serviceService.loadServices()
            
            logger.info("Services initialized and data loaded")
        } catch {
            logger.error("Failed to initialize services: \(error.localizedDescription)")
            throw ServiceInitializationError.initializationFailed(error)
        }
    }
    
    /// Shutdown all services and repositories
    func shutdown() async throws {
        logger.info("Shutting down ServiceFactory")
        
        // Reset service instances
        resetServices()
        
        // Shutdown repository manager
        try await repositoryManager.shutdown()
        
        logger.info("ServiceFactory shutdown completed")
    }
    
    // MARK: - Service Access Properties
    
    /// Async property to get HymnService
    var hymnService: HymnService {
        get async throws {
            try await createHymnService()
        }
    }
    
    /// Async property to get ServiceService
    var serviceService: ServiceService {
        get async throws {
            try await createServiceService()
        }
    }
    
    // MARK: - Statistics and Diagnostics
    
    /// Get factory statistics
    func getFactoryStats() -> ServiceFactoryStats {
        return ServiceFactoryStats(
            hymnServiceCreated: _hymnService != nil,
            serviceServiceCreated: _serviceService != nil,
            lastAccessTime: Date()
        )
    }
    
    /// Get comprehensive system health
    func getSystemHealth() async -> SystemHealth {
        logger.info("Getting comprehensive system health")
        
        var repositoryHealth: [String: Bool] = [:]
        var hasErrors = false
        
        do {
            repositoryHealth = try await performHealthCheck()
            hasErrors = repositoryHealth.values.contains(false)
        } catch {
            logger.error("Failed to get repository health: \(error.localizedDescription)")
            hasErrors = true
        }
        
        let factoryStats = getFactoryStats()
        
        return SystemHealth(
            repositoryHealth: repositoryHealth,
            servicesCreated: factoryStats.hymnServiceCreated && factoryStats.serviceServiceCreated,
            hasErrors: hasErrors,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types

/// Bundle containing all business logic services
struct ServiceBundle {
    let hymnService: HymnService
    let serviceService: ServiceService
}

/// Statistics about service factory
struct ServiceFactoryStats {
    let hymnServiceCreated: Bool
    let serviceServiceCreated: Bool
    let lastAccessTime: Date
}

/// Comprehensive system health information
struct SystemHealth {
    let repositoryHealth: [String: Bool]
    let servicesCreated: Bool
    let hasErrors: Bool
    let timestamp: Date
    
    var isHealthy: Bool {
        return !hasErrors && servicesCreated && !repositoryHealth.isEmpty
    }
}

// MARK: - Error Types

enum ServiceCreationError: LocalizedError {
    case failedToCreateHymnService(Error)
    case failedToCreateServiceService(Error)
    case repositoryUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateHymnService(let error):
            return "Failed to create HymnService: \(error.localizedDescription)"
        case .failedToCreateServiceService(let error):
            return "Failed to create ServiceService: \(error.localizedDescription)"
        case .repositoryUnavailable(let message):
            return "Repository unavailable: \(message)"
        }
    }
}

enum ServiceInitializationError: LocalizedError {
    case initializationFailed(Error)
    case dataLoadingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Service initialization failed: \(error.localizedDescription)"
        case .dataLoadingFailed(let message):
            return "Data loading failed: \(message)"
        }
    }
}

// MARK: - Environment Extensions

extension View {
    /// Inject service factory into the environment
    func serviceFactory(_ factory: ServiceFactory) -> some View {
        self.environmentObject(factory)
    }
}

// MARK: - Convenience Extensions

extension ServiceFactory {
    
    /// Create a configured service factory ready for use in SwiftUI
    static func createForSwiftUI(dataManager: SwiftDataManager) async throws -> ServiceFactory {
        let factory = try await ServiceFactory.create(dataManager: dataManager)
        
        // Initialize services with data
        try await factory.initializeServices()
        
        return factory
    }
}
