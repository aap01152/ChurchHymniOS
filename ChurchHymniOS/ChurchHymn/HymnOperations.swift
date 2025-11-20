import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

class HymnOperations: ObservableObject, @unchecked Sendable {
    @Published var isImporting = false
    @Published var isExporting = false
    @Published var importProgress: Double = 0.0
    @Published var exportProgress: Double = 0.0
    @Published var progressMessage = ""
    
    // Streaming operations
    @Published var streamingOperations: HymnStreamingOperations
    
    private var context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
        self.streamingOperations = HymnStreamingOperations(context: context)
    }
    
    func updateContext(_ newContext: ModelContext) {
        self.context = newContext
        self.streamingOperations.updateContext(newContext)
    }
    
    // MARK: - Import Operations
    
    func importPlainTextHymn(from url: URL, hymns: [Hymn], onComplete: @escaping (ImportPreview) -> Void, onError: @escaping (ImportError) -> Void) {
        Task {
            await MainActor.run {
                isImporting = true
                importProgress = 0.0
                progressMessage = "Reading file..."
            }
            
            do {
                // Simulate file reading progress
                await MainActor.run {
                    importProgress = 0.2
                    progressMessage = "Parsing content..."
                }
                
                let text = try String(contentsOf: url, encoding: .utf8)
                
                // Check if file is empty
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run {
                        isImporting = false
                    }
                    onError(.emptyFile)
                    return
                }
                
                await MainActor.run {
                    importProgress = 0.4
                    progressMessage = "Validating hymn data..."
                }
                
                guard let hymn = Hymn.fromPlainText(text) else {
                    await MainActor.run {
                        isImporting = false
                    }
                    onError(.invalidFormat("Could not parse plain text format. Please ensure the first non-empty line is the title."))
                    return
                }
                
                await MainActor.run {
                    importProgress = 0.6
                    progressMessage = "Checking for duplicates..."
                }
                
                // Create preview data
                var validHymns: [ImportPreviewHymn] = []
                var duplicateHymns: [ImportPreviewHymn] = []
                let errors: [String] = []
                
                // Check for duplicate titles
                if let existingHymn = hymns.first(where: { $0.title.lowercased() == hymn.title.lowercased() }) {
                    duplicateHymns.append(ImportPreviewHymn(from: hymn, isDuplicate: true, existingHymn: existingHymn))
                } else {
                    validHymns.append(ImportPreviewHymn(from: hymn))
                }
                
                await MainActor.run {
                    importProgress = 0.8
                    progressMessage = "Preparing preview..."
                }
                
                // Create preview and show it
                let preview = ImportPreview(
                    hymns: validHymns,
                    duplicates: duplicateHymns,
                    errors: errors,
                    fileName: url.lastPathComponent
                )
                
                await MainActor.run {
                    importProgress = 1.0
                    progressMessage = "Complete!"
                    
                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isImporting = false
                        onComplete(preview)
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    isImporting = false
                }
                let specificError = getSpecificFileError(error)
                onError(specificError)
            }
        }
    }
    
    func importBatchJSON(from url: URL, hymns: [Hymn], onComplete: @escaping (ImportPreview) -> Void, onError: @escaping (ImportError) -> Void) {
        Task {
            await MainActor.run {
                isImporting = true
                importProgress = 0.0
                progressMessage = "Reading JSON file..."
            }
            
            do {
                await MainActor.run {
                    importProgress = 0.1
                    progressMessage = "Loading file data..."
                }
                
                let data = try Data(contentsOf: url)
                
                // Check if file is empty
                guard !data.isEmpty else {
                    await MainActor.run {
                        isImporting = false
                    }
                    onError(.emptyFile)
                    return
                }
                
                await MainActor.run {
                    importProgress = 0.2
                    progressMessage = "Parsing JSON data..."
                }
                
                guard let importedHymns = Hymn.arrayFromJSON(data) else {
                    await MainActor.run {
                        isImporting = false
                    }
                    onError(.invalidFormat("Could not parse JSON format. Please ensure the file contains valid JSON."))
                    return
                }
                
                guard !importedHymns.isEmpty else {
                    await MainActor.run {
                        isImporting = false
                    }
                    onError(.invalidFormat("No hymns found in the JSON file."))
                    return
                }
                
                await MainActor.run {
                    importProgress = 0.3
                    progressMessage = "Processing \(importedHymns.count) hymns..."
                }
                
                // Create preview data
                var validHymns: [ImportPreviewHymn] = []
                var duplicateHymns: [ImportPreviewHymn] = []
                var errors: [String] = []
                
                let totalHymns = importedHymns.count
                for (index, hymn) in importedHymns.enumerated() {
                    // Update progress for each hymn processed
                    let progress = 0.3 + (Double(index) / Double(totalHymns)) * 0.6
                    await MainActor.run {
                        importProgress = progress
                        progressMessage = "Processing hymn \(index + 1) of \(totalHymns)..."
                    }
                    
                    // Validate hymn has a title
                    guard !hymn.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        errors.append("Hymn missing title")
                        continue
                    }
                    
                    // Check for duplicates
                    if let existingHymn = hymns.first(where: { $0.title.lowercased() == hymn.title.lowercased() }) {
                        duplicateHymns.append(ImportPreviewHymn(from: hymn, isDuplicate: true, existingHymn: existingHymn))
                    } else {
                        validHymns.append(ImportPreviewHymn(from: hymn))
                    }
                }
                
                await MainActor.run {
                    importProgress = 0.9
                    progressMessage = "Preparing preview..."
                }
                
                // Create preview and show it
                let preview = ImportPreview(
                    hymns: validHymns,
                    duplicates: duplicateHymns,
                    errors: errors,
                    fileName: url.lastPathComponent
                )
                
                await MainActor.run {
                    importProgress = 1.0
                    progressMessage = "Complete!"
                    
                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isImporting = false
                        onComplete(preview)
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    isImporting = false
                }
                let specificError = getSpecificFileError(error)
                onError(specificError)
            }
        }
    }
    
    // MARK: - Export Operations
    
    func exportPlainTextHymn(_ hymn: Hymn, to url: URL, onComplete: @escaping () -> Void, onError: @escaping (ImportError) -> Void) {
        Task {
            await MainActor.run {
                isExporting = true
                exportProgress = 0.0
                progressMessage = "Preparing hymn data..."
            }
            
            do {
                await MainActor.run {
                    exportProgress = 0.5
                    progressMessage = "Generating plain text format..."
                }
                
                let text = hymn.toPlainText()
                
                await MainActor.run {
                    exportProgress = 0.8
                    progressMessage = "Writing to file..."
                }
                
                try text.write(to: url, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    exportProgress = 1.0
                    progressMessage = "Export complete!"
                    
                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExporting = false
                        onComplete()
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    isExporting = false
                }
                let specificError = getSpecificExportError(error, operation: "plain text")
                onError(specificError)
            }
        }
    }
    
    func exportSingleJSONHymn(_ hymn: Hymn, to url: URL, onComplete: @escaping () -> Void, onError: @escaping (ImportError) -> Void) {
        Task {
            await MainActor.run {
                isExporting = true
                exportProgress = 0.0
                progressMessage = "Preparing hymn data..."
            }
            
            do {
                await MainActor.run {
                    exportProgress = 0.3
                    progressMessage = "Generating JSON format..."
                }
                
                guard let data = hymn.toJSON(pretty: true) else {
                    await MainActor.run {
                        isExporting = false
                    }
                    onError(.invalidFormat("Failed to generate JSON data for hymn '\(hymn.title)'. The hymn data may be corrupted."))
                    return
                }
                
                await MainActor.run {
                    exportProgress = 0.7
                    progressMessage = "Writing to file..."
                }
                
                try data.write(to: url)
                
                await MainActor.run {
                    exportProgress = 1.0
                    progressMessage = "Export complete!"
                    
                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExporting = false
                        onComplete()
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    isExporting = false
                }
                let specificError = getSpecificExportError(error, operation: "JSON")
                onError(specificError)
            }
        }
    }
    
    func exportBatchJSON(_ hymns: [Hymn], to url: URL, onComplete: @escaping () -> Void, onError: @escaping (ImportError) -> Void) {
        Task {
            await MainActor.run {
                isExporting = true
                exportProgress = 0.0
                progressMessage = "Preparing \(hymns.count) hymns for export..."
            }
            
            do {
                await MainActor.run {
                    exportProgress = 0.2
                    progressMessage = "Generating JSON data..."
                }
                
                guard let data = Hymn.arrayToJSON(hymns, pretty: true) else {
                    await MainActor.run {
                        isExporting = false
                    }
                    onError(.invalidFormat("Failed to generate JSON data for \(hymns.count) hymns. Some hymn data may be corrupted."))
                    return
                }
                
                await MainActor.run {
                    exportProgress = 0.6
                    progressMessage = "Writing \(hymns.count) hymns to file..."
                }
                
                try data.write(to: url)
                
                await MainActor.run {
                    exportProgress = 1.0
                    progressMessage = "Export complete! \(hymns.count) hymns exported."
                    
                    // Small delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExporting = false
                        onComplete()
                    }
                }
                
            } catch let error as NSError {
                await MainActor.run {
                    isExporting = false
                }
                let specificError = getSpecificExportError(error, operation: "JSON")
                onError(specificError)
            }
        }
    }
    
    // MARK: - Streaming Operations
    
    func importLargeJSONStreaming(
        from url: URL, 
        hymns: [Hymn],
        onComplete: @escaping (ImportPreview) -> Void,
        onError: @escaping (ImportError) -> Void
    ) {
        streamingOperations.importLargeJSONStreaming(
            from: url,
            hymns: hymns,
            onProgress: { progress in
                // Update progress for UI
                Task { @MainActor in
                    self.importProgress = progress.percentage
                    self.progressMessage = progress.currentPhase
                }
            },
            onComplete: onComplete,
            onError: onError
        )
    }
    
    func exportLargeJSONStreaming(
        hymns: [Hymn],
        to url: URL,
        onComplete: @escaping () -> Void,
        onError: @escaping (ImportError) -> Void
    ) {
        streamingOperations.exportLargeJSONStreaming(
            hymns: hymns,
            to: url,
            onProgress: { progress in
                // Update progress for UI
                Task { @MainActor in
                    self.exportProgress = progress.hymnsPercentage
                    self.progressMessage = progress.currentPhase
                }
            },
            onComplete: onComplete,
            onError: onError
        )
    }
    
    // MARK: - Error Handling
    
    private func getSpecificFileError(_ error: NSError) -> ImportError {
        switch error.code {
        case NSFileReadNoPermissionError:
            return .permissionDenied
        case NSFileReadNoSuchFileError:
            return .fileNotFound
        case NSFileReadCorruptFileError:
            return .corruptedData("File appears to be corrupted")
        case NSFileReadInapplicableStringEncodingError:
            return .invalidFormat("File encoding is not supported. Please ensure the file uses UTF-8 encoding.")
        case NSFileReadTooLargeError:
            return .fileReadFailed("File is too large to read")
        case NSFileReadUnknownStringEncodingError:
            return .invalidFormat("Unknown file encoding. Please ensure the file uses UTF-8 encoding.")
        default:
            return .fileReadFailed(error.localizedDescription)
        }
    }
    
    private func getSpecificExportError(_ error: NSError, operation: String) -> ImportError {
        switch error.code {
        case NSFileWriteNoPermissionError:
            return .permissionDenied
        case NSFileWriteOutOfSpaceError:
            return .fileReadFailed("Not enough disk space to save the \(operation) file")
        case NSFileWriteVolumeReadOnlyError:
            return .fileReadFailed("Cannot write to read-only volume")
        case NSFileWriteFileExistsError:
            return .fileReadFailed("A file with the same name already exists")
        case NSFileWriteInapplicableStringEncodingError:
            return .invalidFormat("Cannot encode \(operation) data with the current encoding")
        default:
            return .fileReadFailed("Failed to export \(operation): \(error.localizedDescription)")
        }
    }
} 
