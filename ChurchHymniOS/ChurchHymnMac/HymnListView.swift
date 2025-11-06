import SwiftUI
import SwiftData

struct HymnListView: View {
    let hymns: [Hymn]
    @Binding var selected: Hymn?
    @Binding var selectedHymnsForDelete: Set<UUID>
    @Binding var isMultiSelectMode: Bool
    @Binding var editHymn: Hymn?
    @Binding var showingEdit: Bool
    @Binding var hymnToDelete: Hymn?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingBatchDeleteConfirmation: Bool
    
    // Add toolbar-related bindings
    @Binding var newHymn: Hymn?
    @Binding var importType: ImportType?
    @Binding var currentImportType: ImportType?
    @Binding var selectedHymnsForExport: Set<UUID>
    @Binding var showingExportSelection: Bool
    @Binding var showingImportHelp: Bool
    @Binding var showingManageWindow: Bool
    
    let context: ModelContext
    let onPresent: (Hymn) -> Void
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .title
    
    enum SortOption: String, CaseIterable, Identifiable {
        case title = "Title"
        case number = "Number"
        case key = "Key"
        case author = "Author"
        
        var id: String { self.rawValue }
    }
    
    var filteredHymns: [Hymn] {
        let filtered: [Hymn]
        if searchText.isEmpty {
            filtered = hymns
        } else {
            filtered = hymns.filter { hymn in
                let searchQuery = searchText.lowercased()
                // Search in title
                if hymn.title.lowercased().contains(searchQuery) {
                    return true
                }
                // Search in song number if present
                if let number = hymn.songNumber,
                   String(number).contains(searchQuery) {
                    return true
                }
                // Search in lyrics if present
                if let lyrics = hymn.lyrics,
                   lyrics.lowercased().contains(searchQuery) {
                    return true
                }
                // Search in author if present
                if let author = hymn.author,
                   author.lowercased().contains(searchQuery) {
                    return true
                }
                return false
            }
        }
        // Sort based on selected option
        switch sortOption {
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .number:
            return filtered.sorted {
                ($0.songNumber ?? Int.max) < ($1.songNumber ?? Int.max)
            }
        case .key:
            return filtered.sorted {
                ($0.musicalKey ?? "").localizedCaseInsensitiveCompare($1.musicalKey ?? "") == .orderedAscending
            }
        case .author:
            return filtered.sorted {
                ($0.author ?? "").localizedCaseInsensitiveCompare($1.author ?? "") == .orderedAscending
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider above search bar
            Divider()
            
            // Toolbar section with icons (aligned and colored like Song tab)
            HStack(spacing: 24) {
                Spacer()
                
                // Add Hymn Button
                Button(action: {
                    let hymn = Hymn(title: "")
                    context.insert(hymn)
                    newHymn = hymn
                    selected = hymn
                    showingEdit = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text("Add")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add new hymn")
                
                // Import Button
                Button(action: {
                    importType = .auto
                    currentImportType = .auto
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title)
                        Text("Import")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Import hymns from text or JSON files")
                
                // Export Menu
                Menu {
                    Button("Export Selected") {
                        if let hymn = selected {
                            selectedHymnsForExport = [hymn.id]
                            showingExportSelection = true
                        }
                    }
                    .disabled(selected == nil)
                    Button("Export Multiple") {
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    Button("Export All") {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                    Button("Export Large Collection") {
                        selectedHymnsForExport = Set(hymns.map { $0.id })
                        showingExportSelection = true
                    }
                    .disabled(hymns.isEmpty)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                        Text("Export")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Export hymns")
                
                // Manage Menu
                Menu {
                    Button(isMultiSelectMode ? "Exit Multi-Select" : "Multi-Select") {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedHymnsForDelete.removeAll()
                        }
                    }
                    .foregroundColor(isMultiSelectMode ? .orange : .blue)
                    if isMultiSelectMode {
                        Divider()
                        Button("Select All") {
                            selectedHymnsForDelete = Set(hymns.map { $0.id })
                        }
                        .disabled(hymns.isEmpty)
                        Button("Deselect All") {
                            selectedHymnsForDelete.removeAll()
                        }
                        .disabled(selectedHymnsForDelete.isEmpty)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title)
                        Text("Manage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Manage selection mode")
                
                // Help Button
                // Removed as requested
                // Button(action: {
                //     showingImportHelp = true
                // }) {
                //     VStack(spacing: 4) {
                //         Image(systemName: "questionmark.circle")
                //             .font(.title)
                //         Text("Help")
                //             .font(.caption)
                //             .foregroundColor(.secondary)
                //     }
                // }
                // .buttonStyle(PlainButtonStyle())
                // .help("Show import-file help")
                
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            
            // Sorting options
            Picker("Sort by", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.rawValue).tag(option as SortOption)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            Divider()
            
            // Hymns list
            List(filteredHymns, id: \.id) { hymn in
                HymnRow(
                    hymn: hymn,
                    isSelected: selected?.id == hymn.id,
                    isMultiSelectMode: isMultiSelectMode,
                    isMarkedForDelete: selectedHymnsForDelete.contains(hymn.id),
                    onToggleDelete: {
                        if selectedHymnsForDelete.contains(hymn.id) {
                            selectedHymnsForDelete.remove(hymn.id)
                        } else {
                            selectedHymnsForDelete.insert(hymn.id)
                        }
                    },
                    onSelect: {
                        if !isMultiSelectMode {
                            selected = hymn
                        }
                    },
                    onEdit: {
                        editHymn = hymn
                        selected = hymn
                        showingEdit = true
                    },
                    onDelete: {
                        if isMultiSelectMode {
                            selectedHymnsForDelete.insert(hymn.id)
                            showingBatchDeleteConfirmation = true
                        } else {
                            hymnToDelete = hymn
                            selected = hymn
                            showingDeleteConfirmation = true
                        }
                    }
                )
                .listRowBackground((selected?.id == hymn.id) ? Color.accentColor.opacity(0.06) : Color.clear)
            }
            .listStyle(PlainListStyle())
            
            // Footer with total count
            HStack {
                Spacer()
                Text("\(filteredHymns.count) of \(hymns.count) hymns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(.systemBackground))
        }
        .frame(minWidth: 250)
    }
}

// Custom SearchBar to ensure immediate updates
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.body)
            
            TextField("Search hymns...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.body)
                // Add these modifiers to ensure immediate updates
                .onChange(of: text) { oldValue, newValue in
                    // Force immediate update
                    text = newValue
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// Separate view for hymn row to reduce type-checking complexity
struct HymnRow: View {
    let hymn: Hymn
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let isMarkedForDelete: Bool
    let onToggleDelete: () -> Void
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Image(systemName: isMarkedForDelete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isMarkedForDelete ? .blue : .gray)
                    .onTapGesture {
                        onToggleDelete()
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(hymn.title)
                    .font(.headline)
                    .tag(hymn)
                
                HStack(spacing: 8) {
                    if let number = hymn.songNumber {
                        Text("#\(number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    if let key = hymn.musicalKey {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    
                    if let author = hymn.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                }
            }
        )
        .overlay(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
        )
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
} 