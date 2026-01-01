import SwiftUI
import UniformTypeIdentifiers

// MARK: - Extensions for UI Display

extension ExportFormat {
    var displayName: String {
        return description
    }
    
    var fileExtension: String {
        switch self {
        case .json:
            return "json"
        case .plainText:
            return "txt"
        }
    }
}

extension DuplicateResolution {
    var displayName: String {
        return description
    }
}

extension ImportType {
    var displayName: String {
        switch self {
        case .auto:
            return "Auto-detect"
        case .plainText:
            return "Plain Text"
        case .json:
            return "JSON"
        }
    }
}

// MARK: - Import Preview Types

struct ImportPreviewHymn: Identifiable {
    let id = UUID()
    let title: String
    let lyrics: String?
    let musicalKey: String?
    let author: String?
    let copyright: String?
    let notes: String?
    let tags: [String]?
    let songNumber: Int?
    let isDuplicate: Bool
    let existingHymn: Hymn?
    
    init(from hymn: Hymn, isDuplicate: Bool = false, existingHymn: Hymn? = nil) {
        self.title = hymn.title
        self.lyrics = hymn.lyrics
        self.musicalKey = hymn.musicalKey
        self.author = hymn.author
        self.copyright = hymn.copyright
        self.notes = hymn.notes
        self.tags = hymn.tags
        self.songNumber = hymn.songNumber
        self.isDuplicate = isDuplicate
        self.existingHymn = existingHymn
    }
}

struct ImportPreview: @unchecked Sendable {
    let hymns: [ImportPreviewHymn]
    let duplicates: [ImportPreviewHymn]
    let errors: [String]
    let fileName: String
    
    var totalHymns: Int { hymns.count + duplicates.count }
    var validHymns: Int { hymns.count }
    var duplicateCount: Int { duplicates.count }
    var errorCount: Int { errors.count }
}

// MARK: - Import Preview View

struct ImportPreviewView: View {
    let preview: ImportPreview
    @ObservedObject var importManager: ImportExportManager
    let onComplete: (Bool) -> Void
    
    @State private var selectedHymns: Set<UUID> = []
    @State private var duplicateResolution: DuplicateResolution = .skip
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(NSLocalizedString("import.preview_title", comment: "Import Preview"))
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(preview.fileName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: NSLocalizedString("import.total", comment: "%d total"), preview.hymns.count + preview.duplicates.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !preview.duplicates.isEmpty {
                                Text(String(format: NSLocalizedString("import.duplicates", comment: "%d duplicates"), preview.duplicates.count))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    if !preview.errors.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(preview.errors, id: \.self) { error in
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .frame(maxHeight: 60)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Duplicate resolution picker
                if !preview.duplicates.isEmpty {
                    VStack {
                        Text("Duplicate Resolution")
                            .font(.headline)
                            .padding(.top)
                        
                        Picker("Resolution", selection: $duplicateResolution) {
                            ForEach(DuplicateResolution.allCases, id: \.self) { resolution in
                                Text(resolution.displayName)
                                    .tag(resolution)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color(.secondarySystemBackground))
                }
                
                // Content list
                List {
                    if !preview.hymns.isEmpty {
                        Section("New Hymns (\(preview.hymns.count))") {
                            ForEach(preview.hymns) { hymn in
                                ImportPreviewRowView(
                                    hymn: hymn,
                                    isSelected: selectedHymns.contains(hymn.id),
                                    onToggle: { toggleSelection(hymn.id) }
                                )
                            }
                        }
                    }
                    
                    if !preview.duplicates.isEmpty {
                        Section("Duplicates (\(preview.duplicates.count))") {
                            ForEach(preview.duplicates) { hymn in
                                ImportPreviewRowView(
                                    hymn: hymn,
                                    isSelected: selectedHymns.contains(hymn.id),
                                    onToggle: { toggleSelection(hymn.id) },
                                    isDuplicate: true
                                )
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete(false)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        Task {
                            await processImport()
                        }
                    }
                    .disabled(selectedHymns.isEmpty || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ImportProgressOverlay(manager: importManager)
                }
            }
        }
        .onAppear {
            // Select all new hymns by default
            selectedHymns = Set(preview.hymns.map { $0.id })
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedHymns.contains(id) {
            selectedHymns.remove(id)
        } else {
            selectedHymns.insert(id)
        }
    }
    
    private func processImport() async {
        isProcessing = true
        let success = await importManager.finalizeImport(
            preview,
            selectedIds: selectedHymns,
            duplicateResolution: duplicateResolution
        )
        isProcessing = false
        onComplete(success)
    }
}

struct ImportPreviewRowView: View {
    let hymn: ImportPreviewHymn
    let isSelected: Bool
    let onToggle: () -> Void
    let isDuplicate: Bool
    
    init(hymn: ImportPreviewHymn, isSelected: Bool, onToggle: @escaping () -> Void, isDuplicate: Bool = false) {
        self.hymn = hymn
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.isDuplicate = isDuplicate
    }
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hymn.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let author = hymn.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isDuplicate, let existing = hymn.existingHymn {
                    Text("Conflicts with: \(existing.title)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct ImportProgressOverlay: View {
    @ObservedObject var manager: ImportExportManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: manager.importProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text(manager.progressMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if manager.importProgress > 0 {
                    Text("\(Int(manager.importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

// MARK: - Export Selection View

struct ExportSelectionView: View {
    let hymns: [Hymn]
    @Binding var selectedHymns: Set<UUID>
    @Binding var exportFormat: ExportFormat
    let onExport: ([Hymn], ExportFormat) -> Void
    
    @State private var localSelection: Set<UUID> = []
    
    var selectedHymnObjects: [Hymn] {
        hymns.filter { localSelection.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack {
                    HStack {
                        Text("Export Hymns")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(localSelection.count) of \(hymns.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Format picker
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Quick selection buttons
                    HStack {
                        Button("Select All") {
                            localSelection = Set(hymns.map { $0.id })
                        }
                        .disabled(hymns.isEmpty)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            localSelection.removeAll()
                        }
                        .disabled(localSelection.isEmpty)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Hymn list
                List(hymns) { hymn in
                    HStack {
                        Button(action: {
                            if localSelection.contains(hymn.id) {
                                localSelection.remove(hymn.id)
                            } else {
                                localSelection.insert(hymn.id)
                            }
                        }) {
                            Image(systemName: localSelection.contains(hymn.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(localSelection.contains(hymn.id) ? .accentColor : .secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hymn.title.isEmpty ? "Untitled Hymn" : hymn.title)
                                .font(.headline)
                                .lineLimit(1)
                            
                            if let author = hymn.author, !author.isEmpty {
                                Text(author)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if localSelection.contains(hymn.id) {
                            localSelection.remove(hymn.id)
                        } else {
                            localSelection.insert(hymn.id)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Dismiss without action
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        selectedHymns = localSelection
                        onExport(selectedHymnObjects, exportFormat)
                    }
                    .disabled(localSelection.isEmpty)
                }
            }
        }
        .onAppear {
            localSelection = selectedHymns
        }
    }
}

// MARK: - Export Document

struct HymnExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.plainText] }
    
    let hymns: [Hymn]
    let format: ExportFormat
    
    init(hymns: [Hymn], format: ExportFormat) {
        self.hymns = hymns
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not needed for export-only document
        self.hymns = []
        self.format = .json
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data: Data
        
        switch format {
        case .json:
            guard let jsonData = Hymn.arrayToJSON(hymns, pretty: true) else {
                throw ExportError.serializationFailed
            }
            data = jsonData
            
        case .plainText:
            var content = ""
            for (index, hymn) in hymns.enumerated() {
                content += hymn.toPlainText()
                if index < hymns.count - 1 {
                    content += "\n\n" + String(repeating: "-", count: 50) + "\n\n"
                }
            }
            guard let textData = content.data(using: .utf8) else {
                throw ExportError.serializationFailed
            }
            data = textData
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

enum ExportError: LocalizedError {
    case serializationFailed
    
    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Failed to serialize hymns for export"
        }
    }
}
