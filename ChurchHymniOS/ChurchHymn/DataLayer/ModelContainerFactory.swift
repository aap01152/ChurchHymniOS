//
//  ModelContainerFactory.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import SwiftUI
import SwiftData
import Foundation
import OSLog

/// Factory for creating properly configured ModelContainers with the new architecture
final class ModelContainerFactory {
    
    // MARK: - Properties
    
    private static let logger = Logger(subsystem: "ChurchHymniOS", category: "ModelContainerFactory")
    
    // MARK: - Public Factory Methods
    
    /// Creates a production ModelContainer with full features
    static func createProductionContainer() -> ModelContainer {
        logger.info("Creating production ModelContainer...")
        
        do {
            let container = try createStandardContainer()
            logger.info("Production ModelContainer created successfully")
            return container
        } catch {
            logger.error("Production container creation failed: \(error.localizedDescription)")
            return createFallbackContainer()
        }
    }
    
    /// Creates a development ModelContainer for testing
    static func createDevelopmentContainer() -> ModelContainer {
        logger.info("Creating development ModelContainer...")
        
        do {
            let configuration = ModelConfiguration(
                schema: createSchema(),
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none // Disable CloudKit for development
            )
            
            let container = try ModelContainer(
                for: createSchema(),
                configurations: [configuration]
            )
            
            logger.info("Development ModelContainer created successfully")
            return container
        } catch {
            logger.error("Development container creation failed: \(error.localizedDescription)")
            return createInMemoryContainer()
        }
    }
    
    /// Creates an in-memory container for testing
    static func createTestContainer() -> ModelContainer {
        logger.info("Creating test ModelContainer...")
        
        do {
            let container = createInMemoryContainer()
            logger.info("Test ModelContainer created successfully")
            return container
        } catch {
            logger.error("Test container creation failed - this should never happen")
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }
    
    /// Creates a container with CloudKit integration
    static func createCloudKitContainer() -> ModelContainer {
        logger.info("Creating CloudKit-enabled ModelContainer...")
        
        do {
            let configuration = ModelConfiguration(
                schema: createSchema(),
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .automatic
            )
            
            let container = try ModelContainer(
                for: createSchema(),
                configurations: [configuration]
            )
            
            logger.info("CloudKit ModelContainer created successfully")
            return container
        } catch {
            logger.error("CloudKit container creation failed: \(error.localizedDescription)")
            logger.info("Falling back to local-only container...")
            do {
                return try createStandardContainer()
            } catch {
                logger.error("Standard container creation also failed: \(error.localizedDescription)")
                return createFallbackContainer()
            }
        }
    }
    
    // MARK: - Private Implementation Methods
    
    /// Creates a standard local container
    private static func createStandardContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: createSchema(),
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )
        
        return try ModelContainer(
            for: createSchema(),
            configurations: [configuration]
        )
    }
    
    /// Creates a fallback container if standard creation fails
    private static func createFallbackContainer() -> ModelContainer {
        logger.warning("Creating fallback ModelContainer...")
        
        do {
            // Try with reduced schema first
            let fallbackSchema = Schema([Hymn.self])
            let configuration = ModelConfiguration(
                schema: fallbackSchema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            let container = try ModelContainer(
                for: fallbackSchema,
                configurations: [configuration]
            )
            
            logger.info("Fallback container created with Hymn model only")
            return container
        } catch {
            logger.error("Fallback container creation failed: \(error.localizedDescription)")
            logger.warning("Creating emergency in-memory container...")
            return createInMemoryContainer()
        }
    }
    
    /// Creates an in-memory container as last resort
    private static func createInMemoryContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(
                schema: createSchema(),
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            
            let container = try ModelContainer(
                for: createSchema(),
                configurations: [configuration]
            )
            
            logger.info("In-memory ModelContainer created successfully")
            return container
        } catch {
            // Absolute last resort: minimal in-memory container
            do {
                let minimalSchema = Schema([Hymn.self])
                let container = try ModelContainer(
                    for: minimalSchema,
                    configurations: ModelConfiguration(
                        schema: minimalSchema,
                        isStoredInMemoryOnly: true
                    )
                )
                
                logger.warning("Created minimal in-memory container with Hymn only")
                return container
            } catch {
                logger.error("Failed to create any ModelContainer: \(error.localizedDescription)")
                fatalError("Unable to create any ModelContainer. App cannot continue.")
            }
        }
    }
    
    /// Creates the complete schema for the app
    private static func createSchema() -> Schema {
        return Schema([
            Hymn.self,
            WorshipService.self,
            ServiceHymn.self
        ])
    }
}

// MARK: - Container Manager

/// Manages the lifecycle of ModelContainer and provides access to SwiftDataManager
@MainActor
final class ModelContainerManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInitialized = false
    @Published var initializationError: DataLayerError?
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "ModelContainerManager")
    private var _container: ModelContainer?
    private var _dataManager: SwiftDataManager?
    private var _migrationCoordinator: MigrationCoordinator?
    
    // MARK: - Public Properties
    
    var container: ModelContainer {
        guard let container = _container else {
            logger.error("Attempted to access container before initialization")
            fatalError("ModelContainer not initialized. Call initialize() first.")
        }
        return container
    }
    
    var dataManager: SwiftDataManager {
        get async {
            guard let dataManager = _dataManager else {
                logger.error("Attempted to access dataManager before initialization")
                fatalError("SwiftDataManager not initialized. Call initialize() first.")
            }
            return await dataManager
        }
    }
    
    var migrationCoordinator: MigrationCoordinator {
        guard let coordinator = _migrationCoordinator else {
            logger.error("Attempted to access migrationCoordinator before initialization")
            fatalError("MigrationCoordinator not initialized. Call initialize() first.")
        }
        return coordinator
    }
    
    // MARK: - Initialization
    
    /// Initializes the ModelContainer and related services
    func initialize(environment: AppEnvironment = .production) async {
        logger.info("Initializing ModelContainerManager for \(environment.rawValue) environment")
        
        do {
            // Create container based on environment
            let container: ModelContainer
            
            switch environment {
            case .production:
                container = ModelContainerFactory.createProductionContainer()
            case .development:
                container = ModelContainerFactory.createDevelopmentContainer()
            case .testing:
                container = ModelContainerFactory.createTestContainer()
            case .cloudKit:
                container = ModelContainerFactory.createCloudKitContainer()
            }
            
            // Create SwiftDataManager
            let dataManager = await SwiftDataManager(modelContainer: container)
            
            // Create MigrationCoordinator
            let migrationCoordinator = MigrationCoordinator(dataManager: dataManager)
            
            // Perform health check
            let healthCheck = try await dataManager.performHealthCheck()
            if !healthCheck.isHealthy {
                logger.warning("Health check failed: \(healthCheck.error ?? "Unknown error")")
                throw DataLayerError.containerInitializationFailed(
                    NSError(domain: "HealthCheck", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: healthCheck.error ?? "Health check failed"
                    ])
                )
            }
            
            // Store references
            _container = container
            _dataManager = dataManager
            _migrationCoordinator = migrationCoordinator
            
            // Perform initial migration
            await migrationCoordinator.performMigration()
            
            // Mark as initialized
            isInitialized = true
            initializationError = nil
            
            logger.info("ModelContainerManager initialized successfully")
            
        } catch let error as DataLayerError {
            logger.error("ModelContainerManager initialization failed: \(error.localizedDescription)")
            initializationError = error
            isInitialized = false
        } catch {
            logger.error("ModelContainerManager initialization failed with unexpected error: \(error.localizedDescription)")
            initializationError = DataLayerError.containerInitializationFailed(error)
            isInitialized = false
        }
    }
    
    /// Reinitializes the manager (useful for recovery scenarios)
    func reinitialize() async {
        logger.info("Reinitializing ModelContainerManager...")
        
        // Reset state
        isInitialized = false
        initializationError = nil
        _container = nil
        _dataManager = nil
        _migrationCoordinator = nil
        
        // Initialize again
        await initialize()
    }
    
    /// Shuts down the manager
    func shutdown() async {
        logger.info("Shutting down ModelContainerManager...")
        
        isInitialized = false
        _container = nil
        _dataManager = nil
        _migrationCoordinator = nil
        
        logger.info("ModelContainerManager shutdown completed")
    }
    
    // MARK: - Health Check
    
    /// Performs a health check on the container and data manager
    func performHealthCheck() async -> HealthCheckResult? {
        guard let dataManager = _dataManager else {
            return nil
        }
        
        do {
            return try await dataManager.performHealthCheck()
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            return HealthCheckResult(
                isHealthy: false,
                hymnCount: 0,
                serviceCount: 0,
                serviceHymnCount: 0,
                responseTime: 0,
                lastChecked: Date(),
                error: error.localizedDescription
            )
        }
    }
}

// MARK: - App Environment

/// Represents different app environments
enum AppEnvironment: String, CaseIterable {
    case production = "production"
    case development = "development"
    case testing = "testing"
    case cloudKit = "cloudkit"
    
    var displayName: String {
        switch self {
        case .production: return "Production"
        case .development: return "Development"
        case .testing: return "Testing"
        case .cloudKit: return "CloudKit Enabled"
        }
    }
}

// MARK: - Legacy Compatibility

/// Provides backward compatibility with the old ServiceMigrationManager
struct LegacyServiceMigrationManager {
    
    /// Creates a ModelContainer using the new factory (for backward compatibility)
    static func createModelContainer() -> ModelContainer {
        Logger(subsystem: "ChurchHymniOS", category: "ServiceMigrationManager")
            .info("Legacy createModelContainer called - delegating to new factory")
        
        return ModelContainerFactory.createProductionContainer()
    }
    
    /// Performs migrations using the new migration system (for backward compatibility)
    static func performMigrations(context: ModelContext) {
        Logger(subsystem: "ChurchHymniOS", category: "ServiceMigrationManager")
            .info("Legacy performMigrations called - migration should be handled by new system")
        
        // The new system handles migrations automatically during initialization
        // This is kept for compatibility but doesn't do anything
    }
}

// MARK: - Environment Object Extension

extension View {
    /// Injects the ModelContainerManager into the environment
    func modelContainerManager(_ manager: ModelContainerManager) -> some View {
        self.environmentObject(manager)
    }
}
