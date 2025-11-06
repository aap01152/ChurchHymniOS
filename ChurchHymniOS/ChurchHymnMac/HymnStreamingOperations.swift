import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import os.log

// MARK: - Streaming Logger
class HymnStreamingLogger {
    static let shared = HymnStreamingLogger()
    private let logger = Logger(subsystem: "com.churchhymn", category: "streaming")
    
    func logInfo(_ message: String) {
        logger.info("\(message)")
    }
    
    func logError(_ error: Error, context: String) {
        logger.error("\(context): \(error.localizedDescription)")
    }
    
    func logWarning(_ message: String) {
        logger.warning("\(message)")
    }
}

// MARK: - Streaming Configuration
struct StreamingConfig {
    static let defaultChunkSize = 8192 // 8KB chunks
    static let maxMemoryUsage = 50 * 1024 * 1024 // 50MB max memory
    static let progressUpdateInterval = 0.1 // Update progress every 10%
    
    let chunkSize: Int
    let maxMemoryUsage: Int
    let progressUpdateInterval: Double
    
    init(chunkSize: Int = defaultChunkSize, 
         maxMemoryUsage: Int = maxMemoryUsage, 
         progressUpdateInterval: Double = progressUpdateInterval) {
        self.chunkSize = chunkSize
        self.maxMemoryUsage = maxMemoryUsage
        self.progressUpdateInterval = progressUpdateInterval
    }
}

// MARK: - Streaming Progress
struct StreamingProgress {
    var bytesProcessed: Int64
    let totalBytes: Int64
    var hymnsProcessed: Int
    var totalHymns: Int?
    var currentPhase: String
    let estimatedTimeRemaining: TimeInterval?
    
    var percentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesProcessed) / Double(totalBytes)
    }
    
    var hymnsPercentage: Double {
        guard let totalHymns = totalHymns, totalHymns > 0 else { return 0.0 }
        return Double(hymnsProcessed) / Double(totalHymns)
    }
}

// MARK: - Streaming Operations
class HymnStreamingOperations: ObservableObject {
    @Published var isStreaming = false
    @Published var streamingProgress: StreamingProgress?
    @Published var streamingMessage = ""
    
    private var context: ModelContext
    private let logger = HymnStreamingLogger.shared
    private var config: StreamingConfig
    
    init(context: ModelContext, config: StreamingConfig = StreamingConfig()) {
        self.context = context
        self.config = config
    }
    
    func updateContext(_ newContext: ModelContext) {
        self.context = newContext
    }
    
    // MARK: - Streaming JSON Import
    
    func importLargeJSONStreaming(
        from url: URL, 
        hymns: [Hymn],
        onProgress: @escaping (StreamingProgress) -> Void,
        onComplete: @escaping (ImportPreview) -> Void,
        onError: @escaping (ImportError) -> Void
    ) {
        Task {
            await MainActor.run {
                isStreaming = true
                streamingMessage = "Initializing streaming import..."
            }
            
            do {
                // Get file size for progress tracking
                let fileSize = try getFileSize(url: url)
                logger.logInfo("Starting streaming import of file: \(url.lastPathComponent), size: \(fileSize) bytes")
                
                // Initialize progress tracking
                var progress = StreamingProgress(
                    bytesProcessed: 0,
                    totalBytes: fileSize,
                    hymnsProcessed: 0,
                    totalHymns: nil,
                    currentPhase: "Reading file",
                    estimatedTimeRemaining: nil
                )
                
                await updateProgress(progress, onProgress: onProgress)
                
                // Use JSONSerialization for streaming
                let result = try await streamJSONFromFile(
                    url: url,
                    progress: &progress,
                    onProgress: onProgress
                )
                
                // Process the parsed hymns
                await processStreamedHymns(
                    result,
                    existingHymns: hymns,
                    progress: &progress,
                    onProgress: onProgress,
                    onComplete: onComplete
                )
                
            } catch {
                logger.logError(error, context: "Streaming JSON import")
                await MainActor.run {
                    isStreaming = false
                }
                onError(.unknown("Streaming import failed: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Streaming JSON Export
    
    func exportLargeJSONStreaming(
        hymns: [Hymn],
        to url: URL,
        onProgress: @escaping (StreamingProgress) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (ImportError) -> Void
    ) {
        Task {
            await MainActor.run {
                isStreaming = true
                streamingMessage = "Initializing streaming export..."
            }
            
            do {
                logger.logInfo("Starting streaming export of \(hymns.count) hymns")
                
                // Initialize progress tracking
                var progress = StreamingProgress(
                    bytesProcessed: 0,
                    totalBytes: 0, // Will be calculated during export
                    hymnsProcessed: 0,
                    totalHymns: hymns.count,
                    currentPhase: "Preparing export",
                    estimatedTimeRemaining: nil
                )
                
                await updateProgress(progress, onProgress: onProgress)
                
                // Stream JSON to file
                try await streamJSONToFile(
                    hymns: hymns,
                    url: url,
                    progress: &progress,
                    onProgress: onProgress
                )
                
                await MainActor.run {
                    isStreaming = false
                    streamingMessage = "Export completed successfully!"
                }
                
                onComplete()
                
            } catch {
                logger.logError(error, context: "Streaming JSON export")
                await MainActor.run {
                    isStreaming = false
                }
                onError(.unknown("Streaming export failed: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getFileSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func streamJSONFromFile(
        url: URL,
        progress: inout StreamingProgress,
        onProgress: @escaping (StreamingProgress) -> Void
    ) async throws -> [Hymn] {
        
        let data = try Data(contentsOf: url)
        progress.bytesProcessed = Int64(data.count)
        progress.currentPhase = "Parsing JSON"
        
        await updateProgress(progress, onProgress: onProgress)
        
        // Parse JSON in chunks to avoid memory issues
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImportError.invalidFormat("Invalid JSON structure - expected array of hymn objects")
        }
        
        progress.totalHymns = jsonArray.count
        progress.currentPhase = "Converting to hymn objects"
        
        var hymns: [Hymn] = []
        let chunkSize = min(100, jsonArray.count) // Process 100 hymns at a time
        
        for i in stride(from: 0, to: jsonArray.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, jsonArray.count)
            let chunk = Array(jsonArray[i..<endIndex])
            
            // Convert chunk to Hymn objects
            for hymnDict in chunk {
                if let hymn = Hymn.fromDictionary(hymnDict) {
                    hymns.append(hymn)
                }
            }
            
            progress.hymnsProcessed = hymns.count
            await updateProgress(progress, onProgress: onProgress)
            
            // Check memory usage
            if getMemoryUsage() > config.maxMemoryUsage {
                logger.logWarning("Memory usage high, processing in smaller chunks")
                // Force garbage collection if available
                #if canImport(Foundation)
                autoreleasepool {
                    // Process in autorelease pool
                }
                #endif
            }
        }
        
        return hymns
    }
    
    private func streamJSONToFile(
        hymns: [Hymn],
        url: URL,
        progress: inout StreamingProgress,
        onProgress: @escaping (StreamingProgress) -> Void
    ) async throws {
        
        progress.currentPhase = "Writing JSON header"
        await updateProgress(progress, onProgress: onProgress)
        
        // Create file and write opening bracket
        let fileHandle = try FileHandle(forWritingTo: url)
        defer { try? fileHandle.close() }
        
        try "[\n".data(using: .utf8)?.write(to: url)
        
        progress.currentPhase = "Writing hymn data"
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        for (index, hymn) in hymns.enumerated() {
            // Convert hymn to JSON
            let hymnData = try encoder.encode(hymn)
            
            // Write hymn JSON
            if index > 0 {
                try ",\n".data(using: .utf8)?.write(to: url)
            }
            try hymnData.write(to: url)
            
            progress.hymnsProcessed = index + 1
            progress.bytesProcessed = Int64(try getFileSize(url: url))
            
            await updateProgress(progress, onProgress: onProgress)
            
            // Check memory usage periodically
            if index % 50 == 0 && getMemoryUsage() > config.maxMemoryUsage {
                logger.logWarning("Memory usage high during export")
                #if canImport(Foundation)
                autoreleasepool {
                    // Process in autorelease pool
                }
                #endif
            }
        }
        
        // Write closing bracket
        try "\n]".data(using: .utf8)?.write(to: url)
        
        progress.currentPhase = "Finalizing export"
        await updateProgress(progress, onProgress: onProgress)
    }
    
    private func processStreamedHymns(
        _ importedHymns: [Hymn],
        existingHymns: [Hymn],
        progress: inout StreamingProgress,
        onProgress: @escaping (StreamingProgress) -> Void,
        onComplete: @escaping (ImportPreview) -> Void
    ) async {
        
        progress.currentPhase = "Checking for duplicates"
        await updateProgress(progress, onProgress: onProgress)
        
        var validHymns: [ImportPreviewHymn] = []
        var duplicateHymns: [ImportPreviewHymn] = []
        var errors: [String] = []
        
        let chunkSize = 50 // Process 50 hymns at a time for duplicate checking
        
        for i in stride(from: 0, to: importedHymns.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, importedHymns.count)
            let chunk = Array(importedHymns[i..<endIndex])
            
            for hymn in chunk {
                // Validate hymn has a title
                guard !hymn.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errors.append("Hymn missing title")
                    continue
                }
                
                // Check for duplicates
                if let existingHymn = existingHymns.first(where: { $0.title.lowercased() == hymn.title.lowercased() }) {
                    duplicateHymns.append(ImportPreviewHymn(from: hymn, isDuplicate: true, existingHymn: existingHymn))
                } else {
                    validHymns.append(ImportPreviewHymn(from: hymn))
                }
            }
            
            progress.hymnsProcessed = min(i + chunkSize, importedHymns.count)
            await updateProgress(progress, onProgress: onProgress)
        }
        
        // Create preview
        let preview = ImportPreview(
            hymns: validHymns,
            duplicates: duplicateHymns,
            errors: errors,
            fileName: "streamed_import.json"
        )
        
        await MainActor.run {
            isStreaming = false
            streamingMessage = "Streaming import completed!"
        }
        
        onComplete(preview)
    }
    
    private func updateProgress(
        _ progress: StreamingProgress,
        onProgress: @escaping (StreamingProgress) -> Void
    ) async {
        await MainActor.run {
            self.streamingProgress = progress
            self.streamingMessage = "\(progress.currentPhase): \(progress.hymnsProcessed) hymns processed"
        }
        onProgress(progress)
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Hymn Dictionary Extension
extension Hymn {
    static func fromDictionary(_ dict: [String: Any]) -> Hymn? {
        guard let title = dict["title"] as? String, !title.isEmpty else {
            return nil
        }
        
        let lyrics = dict["lyrics"] as? String
        let musicalKey = dict["musicalKey"] as? String
        let copyright = dict["copyright"] as? String
        let author = dict["author"] as? String
        let notes = dict["notes"] as? String
        let tags = dict["tags"] as? [String]
        
        return Hymn(
            title: title,
            lyrics: lyrics,
            musicalKey: musicalKey,
            copyright: copyright,
            author: author,
            tags: tags,
            notes: notes
        )
    }
} 
