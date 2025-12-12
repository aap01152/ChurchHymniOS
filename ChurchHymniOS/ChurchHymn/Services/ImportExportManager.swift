import Foundation
import SwiftData
import UniformTypeIdentifiers


/// Import/Export manager that bridges legacy functionality with the new service layer
@MainActor
class ImportExportManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isImporting = false
    @Published var isExporting = false
    @Published var importProgress: Double = 0.0
    @Published var exportProgress: Double = 0.0
    @Published var progressMessage = ""
    @Published var importError: ImportError?
    @Published var exportError: ImportError?
    
    // MARK: - Private Properties
    
    private let hymnService: HymnService
    private let serviceService: ServiceService
    private let hymnOperations: HymnOperations
    
    // MARK: - Initialization
    
    init(hymnService: HymnService, serviceService: ServiceService, operations: HymnOperations) {
        self.hymnService = hymnService
        self.serviceService = serviceService
        self.hymnOperations = operations
    }
    
    // MARK: - Import Operations
    
    func importHymnsFromFiles(_ urls: [URL], importType: ImportType) async -> ImportResult {
        guard !isImporting else {
            return ImportResult(success: false, importedCount: 0, errors: ["Import already in progress"])
        }
        
        isImporting = true
        importProgress = 0.0
        progressMessage = "Starting import..."
        importError = nil
        
        var allHymns: [ImportPreviewHymn] = []
        var allDuplicates: [ImportPreviewHymn] = []
        var allErrors: [String] = []
        var totalFiles = urls.count
        
        for (index, url) in urls.enumerated() {
            // Update progress
            importProgress = Double(index) / Double(totalFiles) * 0.8 // Reserve 20% for processing
            progressMessage = "Processing file \(index + 1) of \(totalFiles): \(url.lastPathComponent)"
            
            // Start accessing security scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Auto-detect file type if needed
            let actualImportType = detectImportType(for: url, requestedType: importType)
            
            do {
                let preview = try await importSingleFile(url, importType: actualImportType)
                allHymns.append(contentsOf: preview.hymns)
                allDuplicates.append(contentsOf: preview.duplicates)
                allErrors.append(contentsOf: preview.errors)
            } catch {
                allErrors.append("Error importing \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Final processing
        importProgress = 0.9
        progressMessage = "Finalizing import..."
        
        let result = ImportResult(
            success: !allHymns.isEmpty,
            importedCount: allHymns.count,
            errors: allErrors,
            preview: ImportPreview(
                hymns: allHymns,
                duplicates: allDuplicates,
                errors: allErrors,
                fileName: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files"
            )
        )
        
        importProgress = 1.0
        progressMessage = "Import complete"
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isImporting = false
            self.importProgress = 0.0
            self.progressMessage = ""
        }
        
        return result
    }
    
    private func importSingleFile(_ url: URL, importType: ImportType) async throws -> ImportPreview {
        return try await withCheckedThrowingContinuation { continuation in
            switch importType {
            case .plainText:
                hymnOperations.importPlainTextHymn(
                    from: url,
                    hymns: hymnService.hymns,
                    onComplete: { preview in
                        continuation.resume(returning: preview)
                    },
                    onError: { error in
                        continuation.resume(throwing: error)
                    }
                )
            case .json:
                // Check file size for streaming decision (using do-catch to handle potential errors)
                var fileSize: Int64 = 0
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    fileSize = attributes[.size] as? Int64 ?? 0
                } catch {
                    // If we can't get file size, default to 0 (will use batch import)
                    fileSize = 0
                }
                
                let largeFileThreshold = 10 * 1024 * 1024 // 10MB
                
                if fileSize > largeFileThreshold {
                    hymnOperations.importLargeJSONStreaming(
                        from: url,
                        hymns: hymnService.hymns,
                        onComplete: { preview in
                            continuation.resume(returning: preview)
                        },
                        onError: { error in
                            continuation.resume(throwing: error)
                        }
                    )
                } else {
                    hymnOperations.importBatchJSON(
                        from: url,
                        hymns: hymnService.hymns,
                        onComplete: { preview in
                            continuation.resume(returning: preview)
                        },
                        onError: { error in
                            continuation.resume(throwing: error)
                        }
                    )
                }
            case .auto:
                continuation.resume(throwing: ImportError.unknown("Auto detection failed"))
            }
        }
    }
    
    func finalizeImport(_ preview: ImportPreview, selectedIds: Set<UUID>, duplicateResolution: DuplicateResolution) async -> Bool {
        isImporting = true
        importProgress = 0.0
        progressMessage = "Processing import..."
        
        let selectedValidHymns = preview.hymns.filter { selectedIds.contains($0.id) }
        let selectedDuplicateHymns = preview.duplicates.filter { selectedIds.contains($0.id) }
        
        var successCount = 0
        let totalItems = selectedValidHymns.count + selectedDuplicateHymns.count
        
        // Process valid hymns
        for (index, previewHymn) in selectedValidHymns.enumerated() {
            importProgress = Double(index) / Double(totalItems) * 0.9
            progressMessage = "Importing: \(previewHymn.title)"
            
            let hymn = Hymn(
                title: previewHymn.title,
                lyrics: previewHymn.lyrics,
                musicalKey: previewHymn.musicalKey,
                copyright: previewHymn.copyright,
                author: previewHymn.author,
                tags: previewHymn.tags,
                notes: previewHymn.notes,
                songNumber: previewHymn.songNumber
            )
            
            let success = await hymnService.createHymn(hymn)
            if success {
                successCount += 1
            }
        }
        
        // Process duplicates based on resolution
        for (index, previewHymn) in selectedDuplicateHymns.enumerated() {
            let currentIndex = selectedValidHymns.count + index
            importProgress = Double(currentIndex) / Double(totalItems) * 0.9
            progressMessage = "Processing duplicate: \(previewHymn.title)"
            
            if let existingHymn = previewHymn.existingHymn {
                switch duplicateResolution {
                case .skip:
                    continue
                case .merge:
                    mergeHymnData(existing: existingHymn, new: previewHymn)
                    let success = await hymnService.updateHymn(existingHymn)
                    if success {
                        successCount += 1
                    }
                case .replace:
                    replaceHymnData(existing: existingHymn, new: previewHymn)
                    let success = await hymnService.updateHymn(existingHymn)
                    if success {
                        successCount += 1
                    }
                }
            }
        }
        
        importProgress = 1.0
        progressMessage = "Import complete: \(successCount) hymns processed"
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isImporting = false
            self.importProgress = 0.0
            self.progressMessage = ""
        }
        
        return successCount > 0
    }
    
    // MARK: - Export Operations
    
    func exportHymns(_ hymns: [Hymn], to url: URL, format: ExportFormat) async -> Bool {
        guard !isExporting else { return false }
        
        isExporting = true
        exportProgress = 0.0
        progressMessage = "Starting export..."
        exportError = nil
        
        let success: Bool
        
        do {
            switch format {
            case .plainText:
                success = try await exportPlainText(hymns, to: url)
            case .json:
                success = try await exportJSON(hymns, to: url)
            }
        } catch {
            exportError = .unknown("Export failed: \(error.localizedDescription)")
            success = false
        }
        
        exportProgress = 1.0
        progressMessage = success ? "Export complete" : "Export failed"
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isExporting = false
            self.exportProgress = 0.0
            self.progressMessage = ""
        }
        
        return success
    }
    
    private func exportPlainText(_ hymns: [Hymn], to url: URL) async throws -> Bool {
        exportProgress = 0.1
        progressMessage = "Preparing text export..."
        
        if hymns.count == 1 {
            // Single hymn export
            let content = hymns[0].toPlainText()
            try content.write(to: url, atomically: true, encoding: .utf8)
        } else {
            // Multiple hymns export
            var content = ""
            for (index, hymn) in hymns.enumerated() {
                exportProgress = 0.1 + (Double(index) / Double(hymns.count)) * 0.8
                progressMessage = "Exporting: \(hymn.title)"
                
                content += hymn.toPlainText()
                if index < hymns.count - 1 {
                    content += "\n\n" + String(repeating: "-", count: 50) + "\n\n"
                }
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        
        exportProgress = 0.95
        progressMessage = "Finalizing export..."
        return true
    }
    
    private func exportJSON(_ hymns: [Hymn], to url: URL) async throws -> Bool {
        exportProgress = 0.1
        progressMessage = "Preparing JSON export..."
        
        let largeCollectionThreshold = 1000
        
        if hymns.count > largeCollectionThreshold {
            // Use streaming for large collections
            return try await exportJSONStreaming(hymns, to: url)
        } else {
            // Standard batch export
            let jsonData = Hymn.arrayToJSON(hymns, pretty: true)
            guard let data = jsonData else {
                throw ImportError.unknown("Failed to serialize hymns to JSON")
            }
            
            exportProgress = 0.8
            progressMessage = "Writing JSON file..."
            
            try data.write(to: url)
            
            exportProgress = 0.95
            progressMessage = "Finalizing export..."
            return true
        }
    }
    
    private func exportJSONStreaming(_ hymns: [Hymn], to url: URL) async throws -> Bool {
        exportProgress = 0.1
        progressMessage = "Starting streaming export..."
        
        let outputStream = OutputStream(url: url, append: false)
        outputStream?.open()
        defer { outputStream?.close() }
        
        guard let stream = outputStream else {
            throw ImportError.unknown("Could not create output stream")
        }
        
        // Write array opening
        let openBracket = "[\n".data(using: .utf8)!
        stream.write(openBracket.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, maxLength: openBracket.count)
        
        // Write hymns one by one
        for (index, hymn) in hymns.enumerated() {
            exportProgress = 0.1 + (Double(index) / Double(hymns.count)) * 0.8
            progressMessage = "Streaming: \(hymn.title)"
            
            guard let hymnData = hymn.toJSON(pretty: true) else {
                continue
            }
            
            // Add comma if not first item
            if index > 0 {
                let comma = ",\n".data(using: .utf8)!
                stream.write(comma.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, maxLength: comma.count)
            }
            
            // Write hymn data
            stream.write(hymnData.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, maxLength: hymnData.count)
        }
        
        // Write array closing
        let closeBracket = "\n]".data(using: .utf8)!
        stream.write(closeBracket.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, maxLength: closeBracket.count)
        
        exportProgress = 0.95
        progressMessage = "Finalizing streaming export..."
        return true
    }
    
    // MARK: - Helper Functions
    
    private func detectImportType(for url: URL, requestedType: ImportType) -> ImportType {
        if requestedType != .auto {
            return requestedType
        }
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "json" {
            return .json
        } else if fileExtension == "txt" || fileExtension.isEmpty {
            return detectContentType(for: url)
        }
        
        return .plainText
    }
    
    private func detectContentType(for url: URL) -> ImportType {
        do {
            let data = try Data(contentsOf: url)
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                if let jsonDict = jsonObject as? [String: Any] {
                    if jsonDict["title"] != nil {
                        return .json
                    }
                } else if let jsonArray = jsonObject as? [[String: Any]] {
                    if !jsonArray.isEmpty && jsonArray.first?["title"] != nil {
                        return .json
                    }
                }
            }
            
            return .plainText
        } catch {
            return .plainText
        }
    }
    
    private func mergeHymnData(existing: Hymn, new: ImportPreviewHymn) {
        if (existing.lyrics?.isEmpty ?? true) && !(new.lyrics?.isEmpty ?? true) {
            existing.lyrics = new.lyrics
        }
        if (existing.musicalKey?.isEmpty ?? true) && !(new.musicalKey?.isEmpty ?? true) {
            existing.musicalKey = new.musicalKey
        }
        if (existing.author?.isEmpty ?? true) && !(new.author?.isEmpty ?? true) {
            existing.author = new.author
        }
        if (existing.copyright?.isEmpty ?? true) && !(new.copyright?.isEmpty ?? true) {
            existing.copyright = new.copyright
        }
        if (existing.notes?.isEmpty ?? true) && !(new.notes?.isEmpty ?? true) {
            existing.notes = new.notes
        }
        if (existing.tags?.isEmpty ?? true) && !(new.tags?.isEmpty ?? true) {
            existing.tags = new.tags
        }
        if existing.songNumber == nil && new.songNumber != nil {
            existing.songNumber = new.songNumber
        }
    }
    
    private func replaceHymnData(existing: Hymn, new: ImportPreviewHymn) {
        existing.lyrics = new.lyrics
        existing.musicalKey = new.musicalKey
        existing.author = new.author
        existing.copyright = new.copyright
        existing.notes = new.notes
        existing.tags = new.tags
        existing.songNumber = new.songNumber
    }
    
    // MARK: - Error Handling
    
    func clearErrors() {
        importError = nil
        exportError = nil
    }
}

// MARK: - Supporting Types

struct ImportResult {
    let success: Bool
    let importedCount: Int
    let errors: [String]
    let preview: ImportPreview?
    
    init(success: Bool, importedCount: Int, errors: [String], preview: ImportPreview? = nil) {
        self.success = success
        self.importedCount = importedCount
        self.errors = errors
        self.preview = preview
    }
}

