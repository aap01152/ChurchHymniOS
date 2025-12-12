import Foundation

// MARK: - Service Layer Specific Errors

/// Errors specific to hymn operations in the service layer
enum HymnError: LocalizedError, Identifiable, Sendable {
    case hymnNotFound(UUID)
    case invalidHymnData(String)
    case duplicateHymn(String)
    case hymnInUse(UUID)
    case hymnValidationFailed(String)
    
    var id: String {
        switch self {
        case .hymnNotFound: return "hymnNotFound"
        case .invalidHymnData: return "invalidHymnData"
        case .duplicateHymn: return "duplicateHymn"
        case .hymnInUse: return "hymnInUse"
        case .hymnValidationFailed: return "hymnValidationFailed"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .hymnNotFound(let id):
            return NSLocalizedString("hymn.error.not_found", 
                                    comment: "Hymn not found") + ": \(id)"
        case .invalidHymnData(let reason):
            return NSLocalizedString("hymn.error.invalid_data", 
                                    comment: "Invalid hymn data") + ": \(reason)"
        case .duplicateHymn(let title):
            return NSLocalizedString("hymn.error.duplicate", 
                                    comment: "Duplicate hymn title") + ": '\(title)'"
        case .hymnInUse(let id):
            return NSLocalizedString("hymn.error.in_use", 
                                    comment: "Hymn is currently in use") + ": \(id)"
        case .hymnValidationFailed(let reason):
            return NSLocalizedString("hymn.error.validation_failed", 
                                    comment: "Hymn validation failed") + ": \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .hymnNotFound:
            return NSLocalizedString("hymn.error.recovery.not_found", 
                                    comment: "The hymn may have been deleted. Try refreshing the list.")
        case .invalidHymnData, .hymnValidationFailed:
            return NSLocalizedString("hymn.error.recovery.invalid_data", 
                                    comment: "Please check the hymn information and try again.")
        case .duplicateHymn:
            return NSLocalizedString("hymn.error.recovery.duplicate", 
                                    comment: "Please use a different title for this hymn.")
        case .hymnInUse:
            return NSLocalizedString("hymn.error.recovery.in_use", 
                                    comment: "Remove the hymn from active services before editing.")
        }
    }
}

/// Extended service errors specific to worship service operations
/// These complement the existing ServiceError in ServiceOperations.swift
enum WorshipServiceError: LocalizedError, Identifiable, Sendable {
    case maxHymnsReached(Int)
    case hymnAlreadyInService(UUID, UUID)
    case serviceNotActive(UUID)
    case invalidServiceConfiguration(String)
    case serviceScheduleConflict(Date)
    
    var id: String {
        switch self {
        case .maxHymnsReached: return "maxHymnsReached"
        case .hymnAlreadyInService: return "hymnAlreadyInService"
        case .serviceNotActive: return "serviceNotActive"
        case .invalidServiceConfiguration: return "invalidServiceConfiguration"
        case .serviceScheduleConflict: return "serviceScheduleConflict"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .maxHymnsReached(let max):
            return NSLocalizedString("service.error.max_hymns_reached", 
                                    comment: "Maximum hymns limit reached") + ": \(max)"
        case .hymnAlreadyInService(let hymnId, let serviceId):
            return NSLocalizedString("service.error.hymn_already_in_service", 
                                    comment: "Hymn is already in service")
        case .serviceNotActive(let serviceId):
            return NSLocalizedString("service.error.service_not_active", 
                                    comment: "Service is not active") + ": \(serviceId)"
        case .invalidServiceConfiguration(let reason):
            return NSLocalizedString("service.error.invalid_configuration", 
                                    comment: "Invalid service configuration") + ": \(reason)"
        case .serviceScheduleConflict(let date):
            return NSLocalizedString("service.error.schedule_conflict", 
                                    comment: "Service schedule conflict") + ": \(date.formatted())"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .maxHymnsReached:
            return NSLocalizedString("service.error.recovery.max_hymns", 
                                    comment: "Remove some hymns before adding more.")
        case .hymnAlreadyInService:
            return NSLocalizedString("service.error.recovery.hymn_duplicate", 
                                    comment: "This hymn is already in the service.")
        case .serviceNotActive:
            return NSLocalizedString("service.error.recovery.not_active", 
                                    comment: "Activate the service before adding hymns.")
        case .invalidServiceConfiguration:
            return NSLocalizedString("service.error.recovery.invalid_config", 
                                    comment: "Check the service settings and try again.")
        case .serviceScheduleConflict:
            return NSLocalizedString("service.error.recovery.schedule_conflict", 
                                    comment: "Choose a different date for the service.")
        }
    }
}