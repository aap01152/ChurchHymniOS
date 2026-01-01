//
//  RepositoryProtocols.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation
import SwiftData

// MARK: - Base Repository Protocol

/// Base protocol for all repositories
protocol BaseRepositoryProtocol: Sendable {
    /// Perform a health check on the repository
    func healthCheck() async throws -> Bool
    
    /// Clear any cached data
    func clearCache() async throws
}

// MARK: - Hymn Repository Protocol

/// Protocol for hymn data access operations
protocol HymnRepositoryProtocol: BaseRepositoryProtocol {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all hymns
    func getAllHymns() async throws -> [Hymn]
    
    /// Fetch hymns with sorting and pagination
    func getHymns(sortBy: [SortDescriptor<Hymn>], limit: Int?, offset: Int?) async throws -> [Hymn]
    
    /// Fetch a specific hymn by ID
    func getHymn(by id: UUID) async throws -> Hymn?
    
    /// Fetch hymns by multiple IDs
    func getHymns(by ids: [UUID]) async throws -> [Hymn]
    
    /// Save a new hymn
    func createHymn(_ hymn: Hymn) async throws -> Hymn
    
    /// Create a new hymn from data within proper context
    func createHymnFromData(title: String, lyrics: String?, musicalKey: String?, copyright: String?, author: String?, tags: [String]?, notes: String?, songNumber: Int?) async throws -> Hymn
    
    /// Update an existing hymn
    func updateHymn(_ hymn: Hymn) async throws -> Hymn
    
    /// Delete a hymn
    func deleteHymn(_ hymn: Hymn) async throws
    
    /// Delete hymns by IDs
    func deleteHymns(ids: [UUID]) async throws -> Int
    
    // MARK: - Search and Filter Operations
    
    /// Search hymns by text query
    func searchHymns(query: String, limit: Int?) async throws -> [Hymn]
    
    /// Search hymns in specific fields
    func searchHymns(
        title: String?, 
        lyrics: String?, 
        author: String?, 
        tags: [String]?,
        limit: Int?
    ) async throws -> [Hymn]
    
    /// Filter hymns by criteria
    func filterHymns(
        hasLyrics: Bool?,
        hasAudio: Bool?,
        musicalKey: String?,
        tags: [String]?,
        limit: Int?
    ) async throws -> [Hymn]
    
    /// Get hymns by tag
    func getHymnsByTag(_ tag: String) async throws -> [Hymn]
    
    /// Get hymns by author
    func getHymnsByAuthor(_ author: String) async throws -> [Hymn]
    
    /// Get hymns by musical key
    func getHymnsByMusicalKey(_ key: String) async throws -> [Hymn]
    
    // MARK: - Statistics and Analytics
    
    /// Get total hymn count
    func getHymnCount() async throws -> Int
    
    /// Get count of hymns matching criteria
    func getHymnCount(
        hasLyrics: Bool?,
        hasAudio: Bool?,
        musicalKey: String?,
        tags: [String]?
    ) async throws -> Int
    
    /// Get all unique tags
    func getAllTags() async throws -> [String]
    
    /// Get all unique authors
    func getAllAuthors() async throws -> [String]
    
    /// Get all unique musical keys
    func getAllMusicalKeys() async throws -> [String]
    
    /// Get hymns added in date range
    func getHymnsCreatedBetween(_ startDate: Date, _ endDate: Date) async throws -> [Hymn]
    
    /// Check if a hymn with the same title exists
    func hymnExists(title: String, excludingId: UUID?) async throws -> Bool
}

// MARK: - Service Repository Protocol

/// Protocol for worship service data access operations
protocol ServiceRepositoryProtocol: BaseRepositoryProtocol {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all services
    func getAllServices() async throws -> [WorshipService]
    
    /// Fetch services with sorting and pagination
    func getServices(sortBy: [SortDescriptor<WorshipService>], limit: Int?, offset: Int?) async throws -> [WorshipService]
    
    /// Fetch a specific service by ID
    func getService(by id: UUID) async throws -> WorshipService?
    
    /// Fetch services by multiple IDs
    func getServices(by ids: [UUID]) async throws -> [WorshipService]
    
    /// Create a new service
    func createService(_ service: WorshipService) async throws -> WorshipService
    
    /// Update an existing service
    func updateService(_ service: WorshipService) async throws -> WorshipService
    
    /// Delete a service
    func deleteService(_ service: WorshipService) async throws
    
    /// Delete services by IDs
    func deleteServices(ids: [UUID]) async throws -> Int
    
    // MARK: - Service State Management
    
    /// Get the currently active service
    func getActiveService() async throws -> WorshipService?
    
    /// Set a service as active (deactivating others)
    func setActiveService(_ service: WorshipService) async throws
    
    /// Deactivate all services
    func deactivateAllServices() async throws
    
    /// Get services by active state
    func getServices(isActive: Bool) async throws -> [WorshipService]
    
    // MARK: - Date-based Operations
    
    /// Get services for a specific date
    func getServicesForDate(_ date: Date) async throws -> [WorshipService]
    
    /// Get services in date range
    func getServicesBetween(_ startDate: Date, _ endDate: Date) async throws -> [WorshipService]
    
    /// Get services for today
    func getTodaysServices() async throws -> [WorshipService]
    
    /// Get services for current week
    func getThisWeeksServices() async throws -> [WorshipService]
    
    /// Get services for current month
    func getThisMonthsServices() async throws -> [WorshipService]
    
    // MARK: - Search and Filter Operations
    
    /// Search services by text query
    func searchServices(query: String, limit: Int?) async throws -> [WorshipService]
    
    /// Filter services by criteria
    func filterServices(
        hasNotes: Bool?,
        isActive: Bool?,
        dateRange: DateInterval?,
        limit: Int?
    ) async throws -> [WorshipService]
    
    // MARK: - Statistics and Analytics
    
    /// Get total service count
    func getServiceCount() async throws -> Int
    
    /// Get count of services matching criteria
    func getServiceCount(
        hasNotes: Bool?,
        isActive: Bool?,
        dateRange: DateInterval?
    ) async throws -> Int
    
    /// Get services created in date range
    func getServicesCreatedBetween(_ startDate: Date, _ endDate: Date) async throws -> [WorshipService]
    
    /// Check if a service exists for a specific date
    func serviceExists(for date: Date, excludingId: UUID?) async throws -> Bool
}

// MARK: - Service Hymn Repository Protocol

/// Protocol for service-hymn relationship data access operations
protocol ServiceHymnRepositoryProtocol: BaseRepositoryProtocol {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all service hymns
    func getAllServiceHymns() async throws -> [ServiceHymn]
    
    /// Fetch a specific service hymn by ID
    func getServiceHymn(by id: UUID) async throws -> ServiceHymn?
    
    /// Create a new service hymn
    func createServiceHymn(_ serviceHymn: ServiceHymn) async throws -> ServiceHymn
    
    /// Update an existing service hymn
    func updateServiceHymn(_ serviceHymn: ServiceHymn) async throws -> ServiceHymn
    
    /// Delete a service hymn
    func deleteServiceHymn(_ serviceHymn: ServiceHymn) async throws
    
    // MARK: - Service-Specific Operations
    
    /// Get all hymns for a specific service (ordered by position)
    func getServiceHymns(for serviceId: UUID) async throws -> [ServiceHymn]
    
    /// Get a specific service hymn by service and hymn ID
    func getServiceHymn(serviceId: UUID, hymnId: UUID) async throws -> ServiceHymn?
    
    /// Add a hymn to a service
    func addHymnToService(hymnId: UUID, serviceId: UUID, order: Int?, notes: String?) async throws -> ServiceHymn
    
    /// Remove a hymn from a service
    func removeHymnFromService(hymnId: UUID, serviceId: UUID) async throws
    
    /// Remove all hymns from a service
    func clearService(_ serviceId: UUID) async throws -> Int
    
    // MARK: - Ordering Operations
    
    /// Reorder hymns in a service
    func reorderServiceHymns(serviceId: UUID, hymnIds: [UUID]) async throws
    
    /// Move a hymn within a service
    func moveServiceHymn(serviceId: UUID, hymnId: UUID, to newOrder: Int) async throws
    
    /// Get the next order number for a service
    func getNextOrder(for serviceId: UUID) async throws -> Int
    
    /// Normalize ordering for a service (ensure sequential 0, 1, 2, ...)
    func normalizeOrdering(for serviceId: UUID) async throws
    
    // MARK: - Query Operations
    
    /// Get services that contain a specific hymn
    func getServicesContaining(hymnId: UUID) async throws -> [WorshipService]
    
    /// Check if a hymn is in a specific service
    func isHymnInService(hymnId: UUID, serviceId: UUID) async throws -> Bool
    
    /// Get count of hymns in a service
    func getHymnCount(in serviceId: UUID) async throws -> Int
    
    /// Get count of services using a hymn
    func getServiceCount(for hymnId: UUID) async throws -> Int
    
    // MARK: - Bulk Operations
    
    /// Add multiple hymns to a service
    func addHymnsToService(hymnIds: [UUID], serviceId: UUID, startingOrder: Int?) async throws -> [ServiceHymn]
    
    /// Remove multiple hymns from a service
    func removeHymnsFromService(hymnIds: [UUID], serviceId: UUID) async throws -> Int
    
    /// Copy hymns from one service to another
    func copyServiceHymns(from sourceServiceId: UUID, to targetServiceId: UUID, preserveOrder: Bool) async throws -> [ServiceHymn]
    
    /// Move hymns from one service to another
    func moveServiceHymns(hymnIds: [UUID], from sourceServiceId: UUID, to targetServiceId: UUID) async throws -> [ServiceHymn]
    
    // MARK: - Statistics and Analytics
    
    /// Get total service hymn count
    func getServiceHymnCount() async throws -> Int
    
    /// Get most frequently used hymns across all services
    func getMostUsedHymns(limit: Int?) async throws -> [(hymn: Hymn, useCount: Int)]
    
    /// Get average hymn count per service
    func getAverageHymnCountPerService() async throws -> Double
    
    /// Get services with no hymns
    func getEmptyServices() async throws -> [WorshipService]
    
    /// Get orphaned service hymns (references to non-existent services or hymns)
    func getOrphanedServiceHymns() async throws -> [ServiceHymn]
    
    // MARK: - Validation Operations
    
    /// Validate service hymn integrity
    func validateIntegrity() async throws -> [(issue: String, serviceHymnId: UUID)]
    
    /// Fix ordering issues in all services
    func fixAllOrderingIssues() async throws -> Int
    
    /// Clean up orphaned service hymns
    func cleanupOrphanedServiceHymns() async throws -> Int
}

// MARK: - Repository Factory Protocol

/// Protocol for creating repository instances
protocol RepositoryFactoryProtocol: Sendable {
    func createHymnRepository() async throws -> HymnRepositoryProtocol
    func createServiceRepository() async throws -> ServiceRepositoryProtocol
    func createServiceHymnRepository() async throws -> ServiceHymnRepositoryProtocol
}

// MARK: - Repository Manager Protocol

/// Protocol for managing all repositories
protocol RepositoryManagerProtocol: Sendable {
    var hymnRepository: HymnRepositoryProtocol { get async throws }
    var serviceRepository: ServiceRepositoryProtocol { get async throws }
    var serviceHymnRepository: ServiceHymnRepositoryProtocol { get async throws }
    
    /// Perform health check on all repositories
    func performHealthCheck() async throws -> [String: Bool]
    
    /// Clear all caches
    func clearAllCaches() async throws
    
    /// Shutdown all repositories
    func shutdown() async throws
}