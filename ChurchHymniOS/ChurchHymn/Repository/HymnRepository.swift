//
//  HymnRepository.swift
//  ChurchHymn
//
//  Created by paulo on 08/12/2025.
//

import Foundation
import SwiftData
import OSLog

/// Thread-safe repository for hymn data access operations
@DataActor
final class HymnRepository: HymnRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataManager: SwiftDataManager
    private let cache: HymnCache
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "HymnRepository")
    
    // MARK: - Initialization
    
    init(dataManager: SwiftDataManager, cache: HymnCache = HymnCache()) {
        self.dataManager = dataManager
        self.cache = cache
        logger.info("HymnRepository initialized")
    }
    
    // MARK: - BaseRepositoryProtocol
    
    func healthCheck() async throws -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Test basic operations
            let count = try await dataManager.count(for: Hymn.self)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.info("Health check passed: \(count) hymns, response time: \(duration, format: .fixed(precision: 3))s")
            return true
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            throw RepositoryError.repositoryUnavailable
        }
    }
    
    func clearCache() async throws {
        await cache.clearAll()
        logger.info("Hymn cache cleared")
    }
    
    // MARK: - Basic CRUD Operations
    
    func getAllHymns() async throws -> [Hymn] {
        logger.info("Fetching all hymns")
        
        do {
            let descriptor = FetchDescriptor<Hymn>(
                sortBy: [SortDescriptor(\.title)]
            )
            
            let hymns = try await dataManager.fetch(descriptor)
            
            // Cache the results
            for hymn in hymns {
                await cache.setHymn(hymn)
            }
            
            logger.info("Retrieved \(hymns.count) hymns")
            return hymns
        } catch {
            logger.error("Failed to fetch all hymns: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymns(sortBy: [SortDescriptor<Hymn>], limit: Int?, offset: Int?) async throws -> [Hymn] {
        logger.info("Fetching hymns with custom sorting, limit: \(limit?.description ?? "none"), offset: \(offset?.description ?? "none")")
        
        do {
            var descriptor = FetchDescriptor<Hymn>(sortBy: sortBy)
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            if let offset = offset {
                descriptor.fetchOffset = offset
            }
            
            let hymns = try await dataManager.fetch(descriptor)
            
            // Cache the results
            for hymn in hymns {
                await cache.setHymn(hymn)
            }
            
            logger.info("Retrieved \(hymns.count) hymns with custom parameters")
            return hymns
        } catch {
            logger.error("Failed to fetch hymns with parameters: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymn(by id: UUID) async throws -> Hymn? {
        logger.info("Fetching hymn by ID: \(id)")
        
        // Check cache first
        if let cachedHymn = await cache.getHymn(by: id) {
            logger.info("Hymn found in cache: \(cachedHymn.title)")
            return cachedHymn
        }
        
        do {
            let descriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymn.id == id
                }
            )
            
            let hymn = try await dataManager.fetchFirst(descriptor)
            
            // Cache the result
            if let hymn = hymn {
                await cache.setHymn(hymn)
                logger.info("Hymn found and cached: \(hymn.title)")
            } else {
                logger.info("Hymn not found with ID: \(id)")
            }
            
            return hymn
        } catch {
            logger.error("Failed to fetch hymn by ID: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymns(by ids: [UUID]) async throws -> [Hymn] {
        logger.info("Fetching \(ids.count) hymns by IDs")
        
        var result: [Hymn] = []
        var uncachedIds: [UUID] = []
        
        // Check cache for each ID
        for id in ids {
            if let cachedHymn = await cache.getHymn(by: id) {
                result.append(cachedHymn)
            } else {
                uncachedIds.append(id)
            }
        }
        
        // Fetch uncached hymns from database
        if !uncachedIds.isEmpty {
            do {
                let descriptor = FetchDescriptor<Hymn>(
                    predicate: #Predicate<Hymn> { hymn in
                        uncachedIds.contains(hymn.id)
                    },
                    sortBy: [SortDescriptor(\.title)]
                )
                
                let uncachedHymns = try await dataManager.fetch(descriptor)
                result.append(contentsOf: uncachedHymns)
                
                // Cache the newly fetched hymns
                for hymn in uncachedHymns {
                    await cache.setHymn(hymn)
                }
            } catch {
                logger.error("Failed to fetch hymns by IDs: \(error.localizedDescription)")
                throw DataLayerError.fetchFailed(error)
            }
        }
        
        logger.info("Retrieved \(result.count) hymns by IDs (\(result.count - uncachedIds.count) from cache)")
        return result.sorted { $0.title < $1.title }
    }
    
    func createHymn(_ hymn: Hymn) async throws -> Hymn {
        return try await createHymnFromData(
            title: hymn.title,
            lyrics: hymn.lyrics,
            musicalKey: hymn.musicalKey,
            copyright: hymn.copyright,
            author: hymn.author,
            tags: hymn.tags,
            notes: hymn.notes,
            songNumber: hymn.songNumber
        )
    }
    
    func createHymnFromData(title: String, lyrics: String?, musicalKey: String?, copyright: String?, author: String?, tags: [String]?, notes: String?, songNumber: Int?) async throws -> Hymn {
        logger.info("Creating new hymn: \(title)")
        
        // Check for duplicates by title
        if try await hymnExists(title: title, excludingId: nil) {
            logger.warning("Attempted to create duplicate hymn: \(title)")
            throw RepositoryError.duplicateEntity("Hymn with title '\(title)' already exists")
        }
        
        do {
            // CRITICAL FIX: Create the hymn within the data manager's context
            let hymn = try await dataManager.createAndInsert { context in
                let newHymn = Hymn(
                    title: title,
                    lyrics: lyrics,
                    musicalKey: musicalKey,
                    copyright: copyright,
                    author: author,
                    tags: tags,
                    notes: notes,
                    songNumber: songNumber
                )
                
                // Validate hymn data
                try self.validateHymn(newHymn)
                
                return newHymn
            }
            
            // Cache the new hymn
            await cache.setHymn(hymn)
            
            logger.info("Successfully created hymn: \(title)")
            return hymn
        } catch {
            logger.error("Failed to create hymn '\(title)': \(error.localizedDescription)")
            throw DataLayerError.insertFailed(error)
        }
    }
    
    func updateHymn(_ hymn: Hymn) async throws -> Hymn {
        logger.info("Updating hymn: \(hymn.title)")
        
        // Validate hymn data
        try validateHymn(hymn)
        
        // Check for duplicates (excluding current hymn)
        if try await hymnExists(title: hymn.title, excludingId: hymn.id) {
            logger.warning("Attempted to update hymn to duplicate title: \(hymn.title)")
            throw RepositoryError.duplicateEntity("Another hymn with title '\(hymn.title)' already exists")
        }
        
        do {
            try await dataManager.save()
            
            // Update cache
            await cache.setHymn(hymn)
            
            logger.info("Successfully updated hymn: \(hymn.title)")
            return hymn
        } catch {
            logger.error("Failed to update hymn: \(error.localizedDescription)")
            throw DataLayerError.updateFailed(error)
        }
    }
    
    func deleteHymn(_ hymn: Hymn) async throws {
        logger.info("Deleting hymn: \(hymn.title)")
        
        do {
            try await dataManager.delete(hymn)
            
            // Remove from cache
            await cache.removeHymn(by: hymn.id)
            
            logger.info("Successfully deleted hymn: \(hymn.title)")
        } catch {
            logger.error("Failed to delete hymn: \(error.localizedDescription)")
            throw DataLayerError.deleteFailed(error)
        }
    }
    
    func deleteHymns(ids: [UUID]) async throws -> Int {
        logger.info("Deleting \(ids.count) hymns")
        
        do {
            let deletedCount = try await dataManager.deleteBatch(
                type: Hymn.self,
                predicate: #Predicate<Hymn> { hymn in
                    ids.contains(hymn.id)
                }
            )
            
            // Remove from cache
            for id in ids {
                await cache.removeHymn(by: id)
            }
            
            logger.info("Successfully deleted \(deletedCount) hymns")
            return deletedCount
        } catch {
            logger.error("Failed to delete hymns: \(error.localizedDescription)")
            throw DataLayerError.batchDeleteFailed(error)
        }
    }
    
    // MARK: - Search and Filter Operations
    
    func searchHymns(query: String, limit: Int?) async throws -> [Hymn] {
        logger.info("Searching hymns with query: '\(query)', limit: \(limit?.description ?? "none")")
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }
        
        do {
            var descriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymn.title.localizedStandardContains(trimmedQuery) ||
                    (hymn.lyrics?.localizedStandardContains(trimmedQuery) ?? false) ||
                    (hymn.author?.localizedStandardContains(trimmedQuery) ?? false)
                },
                sortBy: [SortDescriptor(\.title)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Search returned \(hymns.count) hymns")
            return hymns
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func searchHymns(title: String?, lyrics: String?, author: String?, tags: [String]?, limit: Int?) async throws -> [Hymn] {
        logger.info("Advanced search - title: \(title?.description ?? "nil"), lyrics: \(lyrics?.description ?? "nil"), author: \(author?.description ?? "nil"), tags: \(tags?.description ?? "nil")")
        
        do {
            var descriptor = FetchDescriptor<Hymn>(
                predicate: buildAdvancedSearchPredicate(title: title, lyrics: lyrics, author: author, tags: tags),
                sortBy: [SortDescriptor(\.title)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Advanced search returned \(hymns.count) hymns")
            return hymns
        } catch {
            logger.error("Advanced search failed: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func filterHymns(hasLyrics: Bool?, hasAudio: Bool?, musicalKey: String?, tags: [String]?, limit: Int?) async throws -> [Hymn] {
        logger.info("Filtering hymns - hasLyrics: \(hasLyrics?.description ?? "nil"), hasAudio: \(hasAudio?.description ?? "nil"), musicalKey: \(musicalKey ?? "nil"), tags: \(tags?.description ?? "nil")")
        
        do {
            var descriptor = FetchDescriptor<Hymn>(
                predicate: buildFilterPredicate(hasLyrics: hasLyrics, hasAudio: hasAudio, musicalKey: musicalKey, tags: tags),
                sortBy: [SortDescriptor(\.title)]
            )
            
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Filter returned \(hymns.count) hymns")
            return hymns
        } catch {
            logger.error("Filter failed: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnsByTag(_ tag: String) async throws -> [Hymn] {
        logger.info("Fetching hymns by tag: \(tag)")
        
        do {
            let descriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymn.tags?.contains(tag) ?? false
                },
                sortBy: [SortDescriptor(\.title)]
            )
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Found \(hymns.count) hymns with tag: \(tag)")
            return hymns
        } catch {
            logger.error("Failed to fetch hymns by tag: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnsByAuthor(_ author: String) async throws -> [Hymn] {
        logger.info("Fetching hymns by author: \(author)")
        
        do {
            let descriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymn.author?.localizedStandardContains(author) ?? false
                },
                sortBy: [SortDescriptor(\.title)]
            )
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Found \(hymns.count) hymns by author: \(author)")
            return hymns
        } catch {
            logger.error("Failed to fetch hymns by author: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnsByMusicalKey(_ key: String) async throws -> [Hymn] {
        
        do {
            let descriptor = FetchDescriptor<Hymn>(
                predicate: #Predicate<Hymn> { hymn in
                    hymn.musicalKey == key
                },
                sortBy: [SortDescriptor(\.title)]
            )
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Found \(hymns.count) hymns in key: \(key)")
            return hymns
        } catch {
            logger.error("Failed to fetch hymns by musical key: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Statistics and Analytics
    
    func getHymnCount() async throws -> Int {
        do {
            let count = try await dataManager.count(for: Hymn.self)
            logger.info("Total hymn count: \(count)")
            return count
        } catch {
            logger.error("Failed to get hymn count: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnCount(hasLyrics: Bool?, hasAudio: Bool?, musicalKey: String?, tags: [String]?) async throws -> Int {
        do {
            let predicate = buildFilterPredicate(hasLyrics: hasLyrics, hasAudio: hasAudio, musicalKey: musicalKey, tags: tags)
            let count = try await dataManager.count(for: Hymn.self, predicate: predicate)
            logger.info("Filtered hymn count: \(count)")
            return count
        } catch {
            logger.error("Failed to get filtered hymn count: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getAllTags() async throws -> [String] {
        logger.info("Fetching all unique tags")
        
        do {
            let hymns = try await dataManager.fetchAll(Hymn.self)
            
            let allTags = hymns
                .compactMap { $0.tags }
                .flatMap { $0 }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let uniqueTags = Array(Set(allTags)).sorted()
            logger.info("Found \(uniqueTags.count) unique tags")
            return uniqueTags
        } catch {
            logger.error("Failed to fetch all tags: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getAllAuthors() async throws -> [String] {
        logger.info("Fetching all unique authors")
        
        do {
            let hymns = try await dataManager.fetchAll(Hymn.self)
            
            let allAuthors = hymns
                .compactMap { $0.author }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let uniqueAuthors = Array(Set(allAuthors)).sorted()
            logger.info("Found \(uniqueAuthors.count) unique authors")
            return uniqueAuthors
        } catch {
            logger.error("Failed to fetch all authors: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getAllMusicalKeys() async throws -> [String] {
        logger.info("Fetching all unique musical keys")
        
        do {
            let hymns = try await dataManager.fetchAll(Hymn.self)
            
            let allKeys = hymns
                .compactMap { $0.musicalKey }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let uniqueKeys = Array(Set(allKeys)).sorted()
            logger.info("Found \(uniqueKeys.count) unique musical keys")
            return uniqueKeys
        } catch {
            logger.error("Failed to fetch all musical keys: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func getHymnsCreatedBetween(_ startDate: Date, _ endDate: Date) async throws -> [Hymn] {
        logger.info("Fetching hymns created between \(startDate) and \(endDate)")
        
        do {
            // Note: Hymn model doesn't have createdAt, using this as placeholder for when it's added
            let descriptor = FetchDescriptor<Hymn>(
                sortBy: [SortDescriptor(\.title)]
            )
            
            let hymns = try await dataManager.fetch(descriptor)
            logger.info("Found \(hymns.count) hymns in date range")
            return hymns
        } catch {
            logger.error("Failed to fetch hymns by date range: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    func hymnExists(title: String, excludingId: UUID?) async throws -> Bool {
        do {
            let normalized = title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let predicate: Predicate<Hymn>
            
            if let excludingId = excludingId {
                predicate = #Predicate<Hymn> { hymn in
                    hymn.normalizedTitle == normalized && hymn.id != excludingId
                }
            } else {
                predicate = #Predicate<Hymn> { hymn in
                    hymn.normalizedTitle == normalized
                }
            }
            
            let exists = try await dataManager.exists(for: Hymn.self, predicate: predicate)
            logger.info("Hymn exists check for '\(title)': \(exists)")
            return exists
        } catch {
            logger.error("Failed to check hymn existence: \(error.localizedDescription)")
            throw DataLayerError.fetchFailed(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func validateHymn(_ hymn: Hymn) throws {
        let trimmedTitle = hymn.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            throw BusinessLogicError.invalidInput("Hymn title cannot be empty")
        }
        
        if trimmedTitle.count > 500 {
            throw BusinessLogicError.invalidInput("Hymn title cannot exceed 500 characters")
        }
        
        if let lyrics = hymn.lyrics, lyrics.count > 50000 {
            throw BusinessLogicError.invalidInput("Hymn lyrics cannot exceed 50,000 characters")
        }
        
        if let tags = hymn.tags, tags.count > 20 {
            throw BusinessLogicError.invalidInput("Hymn cannot have more than 20 tags")
        }
    }
    
    private func buildAdvancedSearchPredicate(title: String?, lyrics: String?, author: String?, tags: [String]?) -> Predicate<Hymn>? {
        var conditions: [Predicate<Hymn>] = []
        
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            conditions.append(#Predicate<Hymn> { hymn in
                hymn.title.localizedStandardContains(title)
            })
        }
        
        if let lyrics = lyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !lyrics.isEmpty {
            conditions.append(#Predicate<Hymn> { hymn in
                hymn.lyrics?.localizedStandardContains(lyrics) ?? false
            })
        }
        
        if let author = author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
            conditions.append(#Predicate<Hymn> { hymn in
                hymn.author?.localizedStandardContains(author) ?? false
            })
        }
        
        if let tags = tags, !tags.isEmpty {
            for tag in tags {
                conditions.append(#Predicate<Hymn> { hymn in
                    hymn.tags?.contains(tag) ?? false
                })
            }
        }
        
        guard !conditions.isEmpty else { return nil }
        
        // Combine all conditions with AND logic
        return #Predicate<Hymn> { hymn in
            conditions.allSatisfy { condition in condition.evaluate(hymn) }
        }
    }
    
    private func buildFilterPredicate(hasLyrics: Bool?, hasAudio: Bool?, musicalKey: String?, tags: [String]?) -> Predicate<Hymn>? {
        var conditions: [Predicate<Hymn>] = []
        
        if let hasLyrics = hasLyrics {
            if hasLyrics {
                conditions.append(#Predicate<Hymn> { hymn in
                    hymn.lyrics != nil && hymn.lyrics != ""
                })
            } else {
                conditions.append(#Predicate<Hymn> { hymn in
                    hymn.lyrics == nil || hymn.lyrics == ""
                })
            }
        }
        
        // Note: hasAudio is not currently implemented in the Hymn model
        
        if let musicalKey = musicalKey?.trimmingCharacters(in: .whitespacesAndNewlines), !musicalKey.isEmpty {
            conditions.append(#Predicate<Hymn> { hymn in
                hymn.musicalKey == musicalKey
            })
        }
        
        if let tags = tags, !tags.isEmpty {
            for tag in tags {
                conditions.append(#Predicate<Hymn> { hymn in
                    hymn.tags?.contains(tag) ?? false
                })
            }
        }
        
        guard !conditions.isEmpty else { return nil }
        
        // Combine all conditions with AND logic
        return #Predicate<Hymn> { hymn in
            conditions.allSatisfy { condition in condition.evaluate(hymn) }
        }
    }
}

// MARK: - Hymn Cache

/// Thread-safe cache for hymn data
actor HymnCache {
    
    // MARK: - Properties
    
    private var cache: [UUID: Hymn] = [:]
    private var accessTimes: [UUID: Date] = [:]
    private let maxCacheSize = 1000
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private let logger = Logger(subsystem: "ChurchHymniOS", category: "HymnCache")
    
    // MARK: - Cache Operations
    
    func getHymn(by id: UUID) -> Hymn? {
        // Check if cache entry exists and is not expired
        if let accessTime = accessTimes[id],
           Date().timeIntervalSince(accessTime) > cacheExpirationTime {
            // Entry is expired, remove it
            cache.removeValue(forKey: id)
            accessTimes.removeValue(forKey: id)
            return nil
        }
        
        if let hymn = cache[id] {
            // Update access time
            accessTimes[id] = Date()
            return hymn
        }
        
        return nil
    }
    
    func setHymn(_ hymn: Hymn) {
        // Remove old entries if cache is too large
        if cache.count >= maxCacheSize {
            evictOldestEntries()
        }
        
        cache[hymn.id] = hymn
        accessTimes[hymn.id] = Date()
    }
    
    func removeHymn(by id: UUID) {
        cache.removeValue(forKey: id)
        accessTimes.removeValue(forKey: id)
    }
    
    func clearAll() {
        cache.removeAll()
        accessTimes.removeAll()
        logger.info("Hymn cache cleared")
    }
    
    func getCacheStats() -> (count: Int, size: Int) {
        return (count: cache.count, size: maxCacheSize)
    }
    
    // MARK: - Private Methods
    
    private func evictOldestEntries() {
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
        let toEvict = Array(sortedByAccess.prefix(maxCacheSize / 4)) // Evict 25% of cache
        
        for (id, _) in toEvict {
            cache.removeValue(forKey: id)
            accessTimes.removeValue(forKey: id)
        }
        
        logger.info("Evicted \(toEvict.count) entries from hymn cache")
    }
}
