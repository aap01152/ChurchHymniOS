import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export Types
enum ExportType: Identifiable {
    case singlePlainText, singleJSON, batchJSON, multipleJSON
    var id: Int { hashValue }
}

enum ImportType: Identifiable {
    case plainText, json, auto
    var id: Int { hashValue }
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case plainText = "Plain Text"
    
    var description: String {
        switch self {
        case .json:
            return "Export as JSON format"
        case .plainText:
            return "Export as plain text format"
        }
    }
}

// MARK: - Import Error Types
enum ImportError: LocalizedError, Identifiable {
    case fileReadFailed(String)
    case invalidFormat(String)
    case missingTitle
    case emptyFile
    case permissionDenied
    case fileNotFound
    case corruptedData(String)
    case unknown(String)
    
    var id: String {
        switch self {
        case .fileReadFailed(let message): return "fileReadFailed_\(message)"
        case .invalidFormat(let message): return "invalidFormat_\(message)"
        case .missingTitle: return "missingTitle"
        case .emptyFile: return "emptyFile"
        case .permissionDenied: return "permissionDenied"
        case .fileNotFound: return "fileNotFound"
        case .corruptedData(let message): return "corruptedData_\(message)"
        case .unknown(let message): return "unknown_\(message)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let message):
            return "Failed to read file: \(message)"
        case .invalidFormat(let message):
            return "Invalid file format: \(message)"
        case .missingTitle:
            return "Hymn is missing a title"
        case .emptyFile:
            return "The selected file is empty"
        case .permissionDenied:
            return "Permission denied. Please check file permissions."
        case .fileNotFound:
            return "File not found. The file may have been moved or deleted."
        case .corruptedData(let message):
            return "File appears to be corrupted: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var detailedErrorDescription: String {
        switch self {
        case .fileReadFailed(let message):
            return "Failed to read the selected file. This could be due to file permissions, file corruption, or the file being in use by another application.\n\nError details: \(message)\n\nPlease try selecting a different file or check the file permissions."
        case .invalidFormat(let message):
            return "The selected file does not appear to be in the correct format for importing hymns.\n\nError details: \(message)\n\nPlease ensure the file follows the correct import format. You can check the import format documentation for more details."
        case .missingTitle:
            return "One or more hymns in the file are missing titles. All hymns must have a title to be imported.\n\nPlease add titles to the hymns and try importing again."
        case .emptyFile:
            return "The selected file is empty and contains no hymn data.\n\nPlease select a file that contains hymn data in the correct format."
        case .permissionDenied:
            return "Permission denied when trying to access the selected file.\n\nThis could be due to:\n• File permissions preventing access\n• File being in use by another application\n• macOS security restrictions\n\nPlease try selecting a different file or check the file permissions."
        case .fileNotFound:
            return "The selected file could not be found.\n\nThis could be due to:\n• File being moved or deleted\n• File path being invalid\n• File being on a disconnected drive\n\nPlease ensure the file exists and try selecting it again."
        case .corruptedData(let message):
            return "The selected file appears to be corrupted or contains invalid data.\n\nError details: \(message)\n\nPlease try selecting a different file or check if the file has been damaged."
        case .unknown(let message):
            return "An unexpected error occurred while processing the file.\n\nError details: \(message)\n\nPlease try again or contact support if the problem persists."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileReadFailed:
            return "Try selecting a different file or check file permissions"
        case .invalidFormat:
            return "Check the import format documentation and ensure your file follows the correct format"
        case .missingTitle:
            return "Add titles to all hymns in the file before importing"
        case .emptyFile:
            return "Select a file that contains hymn data"
        case .permissionDenied:
            return "Check file permissions or try selecting a different file"
        case .fileNotFound:
            return "Ensure the file exists and try selecting it again"
        case .corruptedData:
            return "Try selecting a different file or check if the file has been damaged"
        case .unknown:
            return "Try again or contact support if the problem persists"
        }
    }
}

// MARK: - Duplicate Resolution
enum DuplicateResolution: String, CaseIterable {
    case skip = "Skip"
    case merge = "Merge"
    case replace = "Replace"
    
    var description: String {
        switch self {
        case .skip:
            return "Skip duplicate hymns"
        case .merge:
            return "Merge new data with existing hymns"
        case .replace:
            return "Replace existing hymns with new data"
        }
    }
}

struct DuplicateHymn {
    let existingHymn: Hymn
    let newHymn: Hymn
    let title: String
    
    init(existing: Hymn, new: Hymn) {
        self.existingHymn = existing
        self.newHymn = new
        self.title = existing.title
    }
} 
