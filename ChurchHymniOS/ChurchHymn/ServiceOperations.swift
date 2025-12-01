//
//  ServiceOperations.swift
//  ChurchHymn
//
//  Created by paulo on 01/12/2025.
//

import SwiftUI
import SwiftData
import Foundation

class ServiceOperations: ObservableObject, @unchecked Sendable {
    @Published var isLoading = false
    @Published var operationProgress: Double = 0.0
    @Published var progressMessage = ""
    @Published var currentService: WorshipService?
    @Published var lastError: ServiceError?
    
    var context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func updateContext(_ newContext: ModelContext) {
        self.context = newContext
    }
    
    // MARK: - Service Management
    
    /// Create a new worship service
    func createService(title: String, date: Date = Date(), notes: String? = nil) async -> Result<WorshipService, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Creating service..."
            operationProgress = 0.0
        }
        
        do {
            let service = WorshipService(
                title: title,
                date: date,
                notes: notes
            )
            
            await MainActor.run {
                operationProgress = 0.5
                progressMessage = "Saving service..."
            }
            
            context.insert(service)
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Service created successfully"
                isLoading = false
            }
            
            return .success(service)
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.creationFailed(error.localizedDescription)
            }
            return .failure(ServiceError.creationFailed(error.localizedDescription))
        }
    }
    
    /// Create today's service with default settings
    func createTodaysService(title: String = "") async -> Result<WorshipService, ServiceError> {
        let serviceTitle = title.isEmpty ? "Today's Service" : title
        return await createService(title: serviceTitle, date: Date())
    }
    
    /// Get the active service (marked as current)
    func getActiveService() -> WorshipService? {
        do {
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: #Predicate<WorshipService> { service in
                    service.isActive == true
                }
            )
            let services = try context.fetch(descriptor)
            return services.first
        } catch {
            print("Error fetching active service: \(error)")
            return nil
        }
    }
    
    /// Set a service as the active (current) service
    func setActiveService(_ service: WorshipService) async -> Result<Void, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Setting active service..."
            operationProgress = 0.0
        }
        
        do {
            // First, deactivate all other services
            let allServicesDescriptor = FetchDescriptor<WorshipService>()
            let allServices = try context.fetch(allServicesDescriptor)
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Updating services..."
            }
            
            for existingService in allServices {
                existingService.setActive(false)
            }
            
            // Then activate the target service
            service.setActive(true)
            
            await MainActor.run {
                operationProgress = 0.7
                progressMessage = "Saving changes..."
                currentService = service
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Active service updated"
                isLoading = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.updateFailed(error.localizedDescription)
            }
            return .failure(ServiceError.updateFailed(error.localizedDescription))
        }
    }
    
    /// Delete a service and all its hymns
    func deleteService(_ service: WorshipService) async -> Result<Void, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Deleting service..."
            operationProgress = 0.0
        }
        
        do {
            // First, delete all service hymns for this service
            let serviceHymnsDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                }
            )
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Removing service hymns..."
            }
            
            let serviceHymns = try context.fetch(serviceHymnsDescriptor)
            for serviceHymn in serviceHymns {
                context.delete(serviceHymn)
            }
            
            await MainActor.run {
                operationProgress = 0.7
                progressMessage = "Removing service..."
            }
            
            // Then delete the service itself
            context.delete(service)
            
            // Clear current service if it was the deleted one
            if currentService?.id == service.id {
                await MainActor.run {
                    currentService = nil
                }
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Service deleted successfully"
                isLoading = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.deletionFailed(error.localizedDescription)
            }
            return .failure(ServiceError.deletionFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Service Hymn Management
    
    /// Add a hymn to a service
    func addHymnToService(hymnId: UUID, service: WorshipService) async -> Result<ServiceHymn, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Adding hymn to service..."
            operationProgress = 0.0
        }
        
        do {
            // Check if hymn is already in service
            let existingDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id && serviceHymn.hymnId == hymnId
                }
            )
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Checking for duplicates..."
            }
            
            let existing = try context.fetch(existingDescriptor)
            if !existing.isEmpty {
                await MainActor.run {
                    isLoading = false
                    lastError = ServiceError.hymnAlreadyInService
                }
                return .failure(ServiceError.hymnAlreadyInService)
            }
            
            // Get next order number
            let nextOrder = await getNextOrderForService(service.id)
            
            await MainActor.run {
                operationProgress = 0.6
                progressMessage = "Creating service hymn..."
            }
            
            let serviceHymn = ServiceHymn.createForService(
                hymnId: hymnId,
                serviceId: service.id,
                nextOrder: nextOrder
            )
            
            context.insert(serviceHymn)
            service.updateTimestamp()
            
            await MainActor.run {
                operationProgress = 0.9
                progressMessage = "Saving..."
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Hymn added to service"
                isLoading = false
            }
            
            return .success(serviceHymn)
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.addHymnFailed(error.localizedDescription)
            }
            return .failure(ServiceError.addHymnFailed(error.localizedDescription))
        }
    }
    
    /// Remove a hymn from a service
    func removeHymnFromService(hymnId: UUID, service: WorshipService) async -> Result<Void, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Removing hymn from service..."
            operationProgress = 0.0
        }
        
        do {
            // Find the service hymn to remove
            let serviceHymnDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id && serviceHymn.hymnId == hymnId
                }
            )
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Finding service hymn..."
            }
            
            let serviceHymns = try context.fetch(serviceHymnDescriptor)
            guard let serviceHymn = serviceHymns.first else {
                await MainActor.run {
                    isLoading = false
                    lastError = ServiceError.hymnNotInService
                }
                return .failure(ServiceError.hymnNotInService)
            }
            
            let removedOrder = serviceHymn.order
            
            await MainActor.run {
                operationProgress = 0.5
                progressMessage = "Removing hymn..."
            }
            
            context.delete(serviceHymn)
            
            // Reorder remaining hymns
            await reorderHymnsAfterRemoval(serviceId: service.id, removedOrder: removedOrder)
            
            service.updateTimestamp()
            
            await MainActor.run {
                operationProgress = 0.9
                progressMessage = "Saving changes..."
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Hymn removed from service"
                isLoading = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.removeHymnFailed(error.localizedDescription)
            }
            return .failure(ServiceError.removeHymnFailed(error.localizedDescription))
        }
    }
    
    /// Reorder hymns in a service (move hymn from one position to another)
    func reorderServiceHymns(service: WorshipService, from sourceIndex: Int, to destinationIndex: Int) async -> Result<Void, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Reordering service hymns..."
            operationProgress = 0.0
        }
        
        do {
            // Get all service hymns for this service, ordered by current order
            let serviceHymnsDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                },
                sortBy: [SortDescriptor(\.order)]
            )
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Fetching service hymns..."
            }
            
            var serviceHymns = try context.fetch(serviceHymnsDescriptor)
            
            // Validate indices
            guard sourceIndex >= 0 && sourceIndex < serviceHymns.count &&
                  destinationIndex >= 0 && destinationIndex < serviceHymns.count &&
                  sourceIndex != destinationIndex else {
                await MainActor.run {
                    isLoading = false
                    lastError = ServiceError.invalidReorderOperation
                }
                return .failure(ServiceError.invalidReorderOperation)
            }
            
            await MainActor.run {
                operationProgress = 0.5
                progressMessage = "Updating order..."
            }
            
            // Perform the move
            let movedHymn = serviceHymns.remove(at: sourceIndex)
            serviceHymns.insert(movedHymn, at: destinationIndex)
            
            // Update all order values
            for (index, serviceHymn) in serviceHymns.enumerated() {
                serviceHymn.updateOrder(index)
            }
            
            service.updateTimestamp()
            
            await MainActor.run {
                operationProgress = 0.9
                progressMessage = "Saving changes..."
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Service hymns reordered"
                isLoading = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.reorderFailed(error.localizedDescription)
            }
            return .failure(ServiceError.reorderFailed(error.localizedDescription))
        }
    }
    
    /// Clear all hymns from a service
    func clearService(_ service: WorshipService) async -> Result<Void, ServiceError> {
        await MainActor.run {
            isLoading = true
            progressMessage = "Clearing service..."
            operationProgress = 0.0
        }
        
        do {
            // Get all service hymns for this service
            let serviceHymnsDescriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                }
            )
            
            await MainActor.run {
                operationProgress = 0.3
                progressMessage = "Finding service hymns..."
            }
            
            let serviceHymns = try context.fetch(serviceHymnsDescriptor)
            
            await MainActor.run {
                operationProgress = 0.5
                progressMessage = "Removing hymns..."
            }
            
            for serviceHymn in serviceHymns {
                context.delete(serviceHymn)
            }
            
            service.updateTimestamp()
            
            await MainActor.run {
                operationProgress = 0.9
                progressMessage = "Saving changes..."
            }
            
            try context.save()
            
            await MainActor.run {
                operationProgress = 1.0
                progressMessage = "Service cleared successfully"
                isLoading = false
            }
            
            return .success(())
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = ServiceError.clearServiceFailed(error.localizedDescription)
            }
            return .failure(ServiceError.clearServiceFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Query Helper Methods
    
    /// Get all services, optionally filtered
    func getAllServices(includeInactive: Bool = true) -> [WorshipService] {
        do {
            var predicate: Predicate<WorshipService>? = nil
            if !includeInactive {
                predicate = #Predicate<WorshipService> { service in
                    service.isActive == true
                }
            }
            
            let descriptor = FetchDescriptor<WorshipService>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching services: \(error)")
            return []
        }
    }
    
    /// Get service hymns for a specific service, ordered by position
    func getServiceHymns(for service: WorshipService) -> [ServiceHymn] {
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id
                },
                sortBy: [SortDescriptor(\.order)]
            )
            
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching service hymns: \(error)")
            return []
        }
    }
    
    /// Check if a hymn is in a specific service
    func isHymnInService(hymnId: UUID, service: WorshipService) -> Bool {
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == service.id && serviceHymn.hymnId == hymnId
                }
            )
            
            let serviceHymns = try context.fetch(descriptor)
            return !serviceHymns.isEmpty
        } catch {
            print("Error checking hymn in service: \(error)")
            return false
        }
    }
    
    /// Get the position of a hymn in a service (1-based indexing)
    func getHymnPositionInService(hymnId: UUID, service: WorshipService) -> Int? {
        let serviceHymns = getServiceHymns(for: service)
        for (index, serviceHymn) in serviceHymns.enumerated() {
            if serviceHymn.hymnId == hymnId {
                return index + 1 // 1-based indexing for display
            }
        }
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    /// Get the next order number for a service
    private func getNextOrderForService(_ serviceId: UUID) async -> Int {
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId
                },
                sortBy: [SortDescriptor(\.order, order: .reverse)]
            )
            
            let serviceHymns = try context.fetch(descriptor)
            let maxOrder = serviceHymns.first?.order ?? -1
            return maxOrder + 1
        } catch {
            print("Error getting next order: \(error)")
            return 0
        }
    }
    
    /// Reorder hymns after one is removed
    private func reorderHymnsAfterRemoval(serviceId: UUID, removedOrder: Int) async {
        do {
            let descriptor = FetchDescriptor<ServiceHymn>(
                predicate: #Predicate<ServiceHymn> { serviceHymn in
                    serviceHymn.serviceId == serviceId && serviceHymn.order > removedOrder
                }
            )
            
            let hymnsToReorder = try context.fetch(descriptor)
            for serviceHymn in hymnsToReorder {
                serviceHymn.updateOrder(serviceHymn.order - 1)
            }
        } catch {
            print("Error reordering hymns after removal: \(error)")
        }
    }
}

// MARK: - Service Error Definitions

enum ServiceError: LocalizedError, Identifiable {
    case creationFailed(String)
    case updateFailed(String)
    case deletionFailed(String)
    case addHymnFailed(String)
    case removeHymnFailed(String)
    case reorderFailed(String)
    case clearServiceFailed(String)
    case hymnAlreadyInService
    case hymnNotInService
    case invalidReorderOperation
    case serviceNotFound
    case contextError(String)
    
    var id: String {
        switch self {
        case .creationFailed: return "creationFailed"
        case .updateFailed: return "updateFailed"
        case .deletionFailed: return "deletionFailed"
        case .addHymnFailed: return "addHymnFailed"
        case .removeHymnFailed: return "removeHymnFailed"
        case .reorderFailed: return "reorderFailed"
        case .clearServiceFailed: return "clearServiceFailed"
        case .hymnAlreadyInService: return "hymnAlreadyInService"
        case .hymnNotInService: return "hymnNotInService"
        case .invalidReorderOperation: return "invalidReorderOperation"
        case .serviceNotFound: return "serviceNotFound"
        case .contextError: return "contextError"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let details):
            return NSLocalizedString("service.error.creation_failed", comment: "Service creation failed") + ": \(details)"
        case .updateFailed(let details):
            return NSLocalizedString("service.error.update_failed", comment: "Service update failed") + ": \(details)"
        case .deletionFailed(let details):
            return NSLocalizedString("service.error.deletion_failed", comment: "Service deletion failed") + ": \(details)"
        case .addHymnFailed(let details):
            return NSLocalizedString("service.error.add_hymn_failed", comment: "Failed to add hymn to service") + ": \(details)"
        case .removeHymnFailed(let details):
            return NSLocalizedString("service.error.remove_hymn_failed", comment: "Failed to remove hymn from service") + ": \(details)"
        case .reorderFailed(let details):
            return NSLocalizedString("service.error.reorder_failed", comment: "Failed to reorder service hymns") + ": \(details)"
        case .clearServiceFailed(let details):
            return NSLocalizedString("service.error.clear_failed", comment: "Failed to clear service") + ": \(details)"
        case .hymnAlreadyInService:
            return NSLocalizedString("service.error.hymn_already_in_service", comment: "Hymn is already in this service")
        case .hymnNotInService:
            return NSLocalizedString("service.error.hymn_not_in_service", comment: "Hymn is not in this service")
        case .invalidReorderOperation:
            return NSLocalizedString("service.error.invalid_reorder", comment: "Invalid reorder operation")
        case .serviceNotFound:
            return NSLocalizedString("service.error.service_not_found", comment: "Service not found")
        case .contextError(let details):
            return NSLocalizedString("service.error.context_error", comment: "Database context error") + ": \(details)"
        }
    }
}
