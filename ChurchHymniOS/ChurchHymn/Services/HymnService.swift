import Foundation
import SwiftData

@MainActor
class HymnService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hymns: [Hymn] = []
    @Published var isLoading = false
    @Published var error: HymnError?
    @Published var searchResults: [Hymn] = []
    @Published var isSearching = false
    @Published var searchError: HymnError?
    
    // MARK: - Private Properties
    
    private let repository: HymnRepositoryProtocol
    private let maxHymnsPerBatch = 100
    
    // MARK: - Initialization
    
    init(repository: HymnRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Main Operations
    
    func loadHymns() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            let fetchedHymns = try await repository.getAllHymns()
            self.hymns = fetchedHymns
        } catch {
            self.error = .invalidHymnData("Failed to load hymns: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func createHymn(_ hymn: Hymn) async -> Bool {
        guard !isLoading else { return false }
        
        // Validate hymn data
        do {
            try validateHymn(hymn)
        } catch let error as HymnError {
            self.error = error
            return false
        } catch {
            self.error = .invalidHymnData(error.localizedDescription)
            return false
        }
        
        isLoading = true
        error = nil
        
        do {
            // Check for duplicate titles
            if try await repository.hymnExists(title: hymn.title, excludingId: nil) {
                self.error = .duplicateHymn(hymn.title)
                isLoading = false
                return false
            }
            
            let createdHymn = try await repository.createHymn(hymn)
            
            print("DEBUG: Hymn created in repository. ID: \(createdHymn.id.uuidString), Title: '\(createdHymn.title)'")
            print("DEBUG: Current hymns array has \(self.hymns.count) items before refresh")
            
            // CRITICAL FIX: Reload fresh data from repository to ensure consistency
            let freshHymns = try await repository.getAllHymns()
            print("DEBUG: Repository now contains \(freshHymns.count) hymns")
            
            // Update our local array with fresh data
            self.hymns = freshHymns
            print("✅ Hymns array refreshed from repository")
            print("DEBUG: Final hymns array has \(self.hymns.count) items")
            
            isLoading = false
            return true
        } catch {
            self.error = .invalidHymnData("Failed to create hymn: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func updateHymn(_ hymn: Hymn) async -> Bool {
        guard !isLoading else { return false }
        
        // Validate hymn data
        do {
            try validateHymn(hymn)
        } catch let error as HymnError {
            self.error = error
            return false
        } catch {
            self.error = .invalidHymnData(error.localizedDescription)
            return false
        }
        
        isLoading = true
        error = nil
        
        do {
            // Check for duplicate titles (excluding current hymn)
            if try await repository.hymnExists(title: hymn.title, excludingId: hymn.id) {
                self.error = .duplicateHymn(hymn.title)
                isLoading = false
                return false
            }
            
            let updatedHymn = try await repository.updateHymn(hymn)
            
            // Update local array
            if let index = hymns.firstIndex(where: { $0.id == updatedHymn.id }) {
                hymns[index] = updatedHymn
                hymns.sort { $0.title < $1.title }
            }
            
            isLoading = false
            return true
        } catch {
            self.error = .invalidHymnData("Failed to update hymn: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func deleteHymn(_ hymn: Hymn) async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        error = nil
        
        do {
            try await repository.deleteHymn(hymn)
            
            // Remove from local array
            hymns.removeAll { $0.id == hymn.id }
            
            isLoading = false
            return true
        } catch {
            self.error = .invalidHymnData("Failed to delete hymn: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func deleteHymns(_ hymnsToDelete: [Hymn]) async -> Int {
        guard !isLoading else { return 0 }
        
        isLoading = true
        error = nil
        
        do {
            let ids = hymnsToDelete.map { $0.id }
            let deletedCount = try await repository.deleteHymns(ids: ids)
            
            // Remove from local array
            let deletedIds = Set(ids)
            hymns.removeAll { deletedIds.contains($0.id) }
            
            isLoading = false
            return deletedCount
        } catch {
            self.error = .invalidHymnData("Failed to delete hymns: \(error.localizedDescription)")
            isLoading = false
            return 0
        }
    }
    
    // MARK: - Search Operations
    
    func searchHymns(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await clearSearchResults()
            return
        }
        
        guard !isSearching else { return }
        
        isSearching = true
        searchError = nil
        
        do {
            let results = try await repository.searchHymns(query: query, limit: maxHymnsPerBatch)
            self.searchResults = results
        } catch {
            self.searchError = .invalidHymnData("Search failed: \(error.localizedDescription)")
        }
        
        isSearching = false
    }
    
    func clearSearchResults() async {
        searchResults = []
        searchError = nil
        isSearching = false
    }
    
    func getHymnsByTag(_ tag: String) async -> [Hymn] {
        do {
            return try await repository.getHymnsByTag(tag)
        } catch {
            self.error = .invalidHymnData("Failed to get hymns by tag: \(error.localizedDescription)")
            return []
        }
    }
    
    func getHymnsByAuthor(_ author: String) async -> [Hymn] {
        do {
            return try await repository.getHymnsByAuthor(author)
        } catch {
            self.error = .invalidHymnData("Failed to get hymns by author: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    func getStatistics() async -> HymnStatistics {
        do {
            let totalCount = try await repository.getHymnCount()
            let tags = try await repository.getAllTags()
            let authors = try await repository.getAllAuthors()
            let musicalKeys = try await repository.getAllMusicalKeys()
            
            return HymnStatistics(
                totalHymns: totalCount,
                uniqueTags: tags.count,
                uniqueAuthors: authors.count,
                uniqueMusicalKeys: musicalKeys.count
            )
        } catch {
            self.error = .invalidHymnData("Failed to get statistics: \(error.localizedDescription)")
            return HymnStatistics(totalHymns: 0, uniqueTags: 0, uniqueAuthors: 0, uniqueMusicalKeys: 0)
        }
    }
    
    // MARK: - Validation
    
    private func validateHymn(_ hymn: Hymn) throws {
        // Validate title
        let trimmedTitle = hymn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw HymnError.invalidHymnData("Title cannot be empty")
        }
        
        if trimmedTitle.count > 200 {
            throw HymnError.invalidHymnData("Title cannot exceed 200 characters")
        }
        
        // Validate lyrics length if present
        if let lyrics = hymn.lyrics, lyrics.count > 10000 {
            throw HymnError.invalidHymnData("Lyrics cannot exceed 10,000 characters")
        }
        
        // Validate song number if present
        if let songNumber = hymn.songNumber, songNumber < 0 {
            throw HymnError.invalidHymnData("Song number cannot be negative")
        }
        
        // Validate tags if present
        if let tags = hymn.tags {
            for tag in tags {
                if tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw HymnError.invalidHymnData("Tags cannot be empty")
                }
            }
            
            if tags.count > 20 {
                throw HymnError.invalidHymnData("Cannot have more than 20 tags")
            }
        }
    }
    
    // MARK: - Cleanup
    
    func clearError() {
        error = nil
    }
    
    func clearSearchError() {
        searchError = nil
    }
}

// MARK: - Supporting Types

struct HymnStatistics {
    let totalHymns: Int
    let uniqueTags: Int
    let uniqueAuthors: Int
    let uniqueMusicalKeys: Int
}