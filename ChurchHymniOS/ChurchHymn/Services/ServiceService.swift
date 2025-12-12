import Foundation
import SwiftData

@MainActor
class ServiceService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var services: [WorshipService] = []
    @Published var activeService: WorshipService?
    @Published var serviceHymns: [ServiceHymn] = []
    @Published var isLoading = false
    @Published var error: BusinessLogicError?
    @Published var isPerformingServiceOperation = false
    @Published var serviceOperationError: WorshipServiceError?
    
    // MARK: - Private Properties
    
    private let serviceRepository: ServiceRepositoryProtocol
    private let hymnRepository: HymnRepositoryProtocol
    private let serviceHymnRepository: ServiceHymnRepositoryProtocol
    private let maxHymnsPerService = 50
    
    // MARK: - Initialization
    
    init(
        serviceRepository: ServiceRepositoryProtocol,
        hymnRepository: HymnRepositoryProtocol,
        serviceHymnRepository: ServiceHymnRepositoryProtocol
    ) {
        self.serviceRepository = serviceRepository
        self.hymnRepository = hymnRepository
        self.serviceHymnRepository = serviceHymnRepository
    }
    
    // MARK: - Service Management
    
    func loadServices() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedServices = try await serviceRepository.getAllServices()
            self.services = fetchedServices
            
            // Load active service
            if let activeService = try await serviceRepository.getActiveService() {
                self.activeService = activeService
                await loadServiceHymns(for: activeService.id)
            }
        } catch {
            self.error = .businessRuleViolation("Failed to load services: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func createService(_ service: WorshipService) async -> Bool {
        guard !isLoading else { return false }
        
        // Validate service data
        do {
            try validateService(service)
        } catch let error as BusinessLogicError {
            self.error = error
            return false
        } catch {
            self.error = .invalidInput("Service validation failed: \(error.localizedDescription)")
            return false
        }
        
        isLoading = true
        error = nil
        
        do {
            let createdService = try await serviceRepository.createService(service)
            self.services.append(createdService)
            self.services.sort { $0.date > $1.date } // Most recent first
            
            isLoading = false
            return true
        } catch {
            self.error = .businessRuleViolation("Failed to create service: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func updateService(_ service: WorshipService) async -> Bool {
        guard !isLoading else { return false }
        
        // Validate service data
        do {
            try validateService(service)
        } catch let error as BusinessLogicError {
            self.error = error
            return false
        } catch {
            self.error = .invalidInput("Service validation failed: \(error.localizedDescription)")
            return false
        }
        
        isLoading = true
        error = nil
        
        do {
            let updatedService = try await serviceRepository.updateService(service)
            
            // Update local array
            if let index = services.firstIndex(where: { $0.id == updatedService.id }) {
                services[index] = updatedService
                services.sort { $0.date > $1.date }
            }
            
            // Update active service if needed
            if activeService?.id == updatedService.id {
                activeService = updatedService
            }
            
            isLoading = false
            return true
        } catch {
            self.error = .businessRuleViolation("Failed to update service: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func deleteService(_ service: WorshipService) async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        error = nil
        
        do {
            try await serviceRepository.deleteService(service)
            
            // Remove from local array
            services.removeAll { $0.id == service.id }
            
            // Clear active service if it was deleted
            if activeService?.id == service.id {
                activeService = nil
                serviceHymns = []
            }
            
            isLoading = false
            return true
        } catch {
            self.error = .businessRuleViolation("Failed to delete service: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Active Service Management
    
    func setActiveService(_ service: WorshipService) async -> Bool {
        guard !isPerformingServiceOperation else { return false }
        
        isPerformingServiceOperation = true
        serviceOperationError = nil
        
        do {
            try await serviceRepository.setActiveService(service)
            self.activeService = service
            
            // Update services array to reflect active state changes
            for index in services.indices {
                services[index].isActive = services[index].id == service.id
            }
            
            // Load hymns for the new active service
            await loadServiceHymns(for: service.id)
            
            isPerformingServiceOperation = false
            return true
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to set active service: \(error.localizedDescription)")
            isPerformingServiceOperation = false
            return false
        }
    }
    
    func deactivateAllServices() async -> Bool {
        guard !isPerformingServiceOperation else { return false }
        
        isPerformingServiceOperation = true
        serviceOperationError = nil
        
        do {
            try await serviceRepository.deactivateAllServices()
            self.activeService = nil
            self.serviceHymns = []
            
            // Update local array
            for index in services.indices {
                services[index].isActive = false
            }
            
            isPerformingServiceOperation = false
            return true
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to deactivate services: \(error.localizedDescription)")
            isPerformingServiceOperation = false
            return false
        }
    }
    
    // MARK: - Service Hymn Management
    
    func loadServiceHymns(for serviceId: UUID) async {
        do {
            let hymns = try await serviceHymnRepository.getServiceHymns(for: serviceId)
            self.serviceHymns = hymns.sorted { $0.order < $1.order }
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to load service hymns: \(error.localizedDescription)")
        }
    }
    
    func addHymnToService(hymnId: UUID, serviceId: UUID, notes: String? = nil) async -> Bool {
        guard !isPerformingServiceOperation else { return false }
        
        // Check if service exists and is not in progress
        guard let service = services.first(where: { $0.id == serviceId }) else {
            self.serviceOperationError = .serviceNotActive(serviceId)
            return false
        }
        
        isPerformingServiceOperation = true
        serviceOperationError = nil
        
        do {
            // Check if hymn is already in service
            if try await serviceHymnRepository.isHymnInService(hymnId: hymnId, serviceId: serviceId) {
                self.serviceOperationError = .hymnAlreadyInService(hymnId, serviceId)
                isPerformingServiceOperation = false
                return false
            }
            
            // Check maximum hymns limit
            let currentHymnCount = try await serviceHymnRepository.getHymnCount(in: serviceId)
            if currentHymnCount >= maxHymnsPerService {
                self.serviceOperationError = .maxHymnsReached(maxHymnsPerService)
                isPerformingServiceOperation = false
                return false
            }
            
            // Add hymn to service
            let serviceHymn = try await serviceHymnRepository.addHymnToService(
                hymnId: hymnId,
                serviceId: serviceId,
                order: nil, // Let repository determine order
                notes: notes
            )
            
            // Update local array if this is the active service
            if activeService?.id == serviceId {
                serviceHymns.append(serviceHymn)
                serviceHymns.sort { $0.order < $1.order }
            }
            
            isPerformingServiceOperation = false
            return true
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to add hymn to service: \(error.localizedDescription)")
            isPerformingServiceOperation = false
            return false
        }
    }
    
    func removeHymnFromService(hymnId: UUID, serviceId: UUID) async -> Bool {
        guard !isPerformingServiceOperation else { return false }
        
        isPerformingServiceOperation = true
        serviceOperationError = nil
        
        do {
            try await serviceHymnRepository.removeHymnFromService(hymnId: hymnId, serviceId: serviceId)
            
            // Update local array if this is the active service
            if activeService?.id == serviceId {
                serviceHymns.removeAll { $0.hymnId == hymnId }
            }
            
            isPerformingServiceOperation = false
            return true
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to remove hymn from service: \(error.localizedDescription)")
            isPerformingServiceOperation = false
            return false
        }
    }
    
    func reorderServiceHymns(serviceId: UUID, hymnIds: [UUID]) async -> Bool {
        guard !isPerformingServiceOperation else { return false }
        
        isPerformingServiceOperation = true
        serviceOperationError = nil
        
        do {
            try await serviceHymnRepository.reorderServiceHymns(serviceId: serviceId, hymnIds: hymnIds)
            
            // Reload service hymns to reflect new order
            if activeService?.id == serviceId {
                await loadServiceHymns(for: serviceId)
            }
            
            isPerformingServiceOperation = false
            return true
        } catch {
            self.serviceOperationError = .invalidServiceConfiguration("Failed to reorder hymns: \(error.localizedDescription)")
            isPerformingServiceOperation = false
            return false
        }
    }
    
    // MARK: - Query Operations
    
    func getServicesForDate(_ date: Date) async -> [WorshipService] {
        do {
            return try await serviceRepository.getServicesForDate(date)
        } catch {
            self.error = .businessRuleViolation("Failed to get services for date: \(error.localizedDescription)")
            return []
        }
    }
    
    func getTodaysServices() async -> [WorshipService] {
        do {
            return try await serviceRepository.getTodaysServices()
        } catch {
            self.error = .businessRuleViolation("Failed to get today's services: \(error.localizedDescription)")
            return []
        }
    }
    
    func getServicesContainingHymn(_ hymnId: UUID) async -> [WorshipService] {
        do {
            return try await serviceHymnRepository.getServicesContaining(hymnId: hymnId)
        } catch {
            self.error = .businessRuleViolation("Failed to get services containing hymn: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    func getServiceStatistics() async -> ServiceStatistics {
        do {
            let totalServices = try await serviceRepository.getServiceCount()
            let averageHymnCount = try await serviceHymnRepository.getAverageHymnCountPerService()
            let mostUsedHymns = try await serviceHymnRepository.getMostUsedHymns(limit: 10)
            
            return ServiceStatistics(
                totalServices: totalServices,
                averageHymnCount: averageHymnCount,
                mostUsedHymns: mostUsedHymns
            )
        } catch {
            self.error = .businessRuleViolation("Failed to get service statistics: \(error.localizedDescription)")
            return ServiceStatistics(totalServices: 0, averageHymnCount: 0, mostUsedHymns: [])
        }
    }
    
    // MARK: - Validation
    
    private func validateService(_ service: WorshipService) throws {
        // Validate title
        let trimmedTitle = service.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw BusinessLogicError.invalidInput("Title cannot be empty")
        }
        
        if trimmedTitle.count > 100 {
            throw BusinessLogicError.invalidInput("Title cannot exceed 100 characters")
        }
        
        // Validate date is not too far in the past
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        
        if service.date < oneYearAgo {
            throw BusinessLogicError.businessRuleViolation("Service date cannot be more than one year in the past")
        }
        
        // Validate notes length if present
        if let notes = service.notes, notes.count > 1000 {
            throw BusinessLogicError.invalidInput("Notes cannot exceed 1,000 characters")
        }
    }
    
    // MARK: - Cleanup
    
    func clearError() {
        error = nil
    }
    
    func clearServiceOperationError() {
        serviceOperationError = nil
    }
}

// MARK: - Supporting Types

struct ServiceStatistics {
    let totalServices: Int
    let averageHymnCount: Double
    let mostUsedHymns: [(hymn: Hymn, useCount: Int)]
}