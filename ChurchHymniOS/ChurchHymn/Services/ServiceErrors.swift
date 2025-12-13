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

/// Import/Export operation errors with detailed user feedback
enum ImportExportError: LocalizedError, Identifiable, Sendable {
    case fileNotFound(String)
    case invalidFileFormat(String)
    case emptyFile(String)
    case permissionDenied(String)
    case hymnTitleMissing(String)
    case fileCorrupted(String)
    case unexpectedError(String)
    case invalidJSON(String)
    case autoDetectionFailed(String)
    
    var id: String {
        switch self {
        case .fileNotFound: return "fileNotFound"
        case .invalidFileFormat: return "invalidFileFormat"
        case .emptyFile: return "emptyFile"
        case .permissionDenied: return "permissionDenied"
        case .hymnTitleMissing: return "hymnTitleMissing"
        case .fileCorrupted: return "fileCorrupted"
        case .unexpectedError: return "unexpectedError"
        case .invalidJSON: return "invalidJSON"
        case .autoDetectionFailed: return "autoDetectionFailed"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return NSLocalizedString("msg.file_not_found", comment: "File not found error") + ": \(filename)"
        case .invalidFileFormat(let format):
            return NSLocalizedString("msg.invalid_file_format", comment: "Invalid file format error") + ": \(format)"
        case .emptyFile(let filename):
            return NSLocalizedString("msg.file_empty", comment: "Empty file error") + ": \(filename)"
        case .permissionDenied(let filename):
            return NSLocalizedString("msg.permission_denied", comment: "Permission denied error") + ": \(filename)"
        case .hymnTitleMissing(let details):
            return NSLocalizedString("msg.hymn_missing_title", comment: "Hymn title missing error") + ": \(details)"
        case .fileCorrupted(let filename):
            return NSLocalizedString("msg.file_corrupted", comment: "File corrupted error") + ": \(filename)"
        case .unexpectedError(let details):
            return NSLocalizedString("msg.unexpected_error", comment: "Unexpected error") + ": \(details)"
        case .invalidJSON(let details):
            return NSLocalizedString("msg.invalid_file_format", comment: "Invalid JSON format") + ": \(details)"
        case .autoDetectionFailed(let filename):
            return NSLocalizedString("msg.auto_detection_failed", comment: "Auto detection failed") + ": \(filename)"
        }
    }
    
    var detailedErrorDescription: String {
        let baseError = errorDescription ?? "Unknown error"
        let recovery = recoverySuggestion ?? ""
        return recovery.isEmpty ? baseError : "\(baseError)\n\n\(recovery)"
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("error.ensure_file_exists", comment: "File not found recovery")
        case .invalidFileFormat, .invalidJSON:
            return NSLocalizedString("error.check_format_docs", comment: "Invalid format recovery")
        case .emptyFile:
            return NSLocalizedString("error.select_file_with_data", comment: "Empty file recovery")
        case .permissionDenied:
            return NSLocalizedString("error.try_different_file", comment: "Permission denied recovery")
        case .hymnTitleMissing:
            return NSLocalizedString("error.add_titles", comment: "Missing titles recovery")
        case .fileCorrupted:
            return NSLocalizedString("error.try_different_file_damaged", comment: "Corrupted file recovery")
        case .unexpectedError, .autoDetectionFailed:
            return NSLocalizedString("error.try_again_contact_support", comment: "Unexpected error recovery")
        }
    }
}