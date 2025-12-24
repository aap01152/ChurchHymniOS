//
//  WorshipService.swift
//  ChurchHymn
//
//  Created by paulo on 01/12/2025.
//

import SwiftUI
import SwiftData
import Foundation

@Model
class WorshipService: Identifiable, Codable, @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var isActive: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var notes: String?
    var worshipHymnsHistory: String? // JSON string of hymns used during worship
    var createdAt: Date
    var updatedAt: Date
    var modelVersion: Int

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        isActive: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        notes: String? = nil,
        worshipHymnsHistory: String? = nil,
        modelVersion: Int = 1
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = date
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.worshipHymnsHistory = worshipHymnsHistory
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelVersion = modelVersion
    }

    // MARK: - Helper Properties
    
    /// Computed property for display title
    var displayTitle: String {
        if title.isEmpty {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return title
    }
    
    /// Computed property to check if service is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Computed property for formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Computed property to get worship hymns used during this service
    var worshipHymnsUsed: [String] {
        guard let historyJson = worshipHymnsHistory,
              let data = historyJson.data(using: .utf8) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to decode worship hymns history: \(error)")
            return []
        }
    }

    // MARK: - Update Methods
    
    /// Update the service's timestamp
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    /// Mark service as active and deactivate others (should be handled by operations class)
    func setActive(_ active: Bool) {
        isActive = active
        updateTimestamp()
    }

    // MARK: - Migration Strategy
    // Use modelVersion to track schema changes
    // Future enhancements: recurrence patterns, service templates, collaboration features

    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, title, date, isActive, isCompleted, completedAt, notes, worshipHymnsHistory, createdAt, updatedAt, modelVersion
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let title = try container.decode(String.self, forKey: .title)
        let date = try container.decode(Date.self, forKey: .date)
        let isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        let isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        let completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let worshipHymnsHistory = try container.decodeIfPresent(String.self, forKey: .worshipHymnsHistory)
        let modelVersion = try container.decodeIfPresent(Int.self, forKey: .modelVersion) ?? 1
        
        self.init(
            id: id,
            title: title,
            date: date,
            isActive: isActive,
            isCompleted: isCompleted,
            completedAt: completedAt,
            notes: notes,
            worshipHymnsHistory: worshipHymnsHistory,
            modelVersion: modelVersion
        )
        
        // Restore timestamps if available
        if let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = createdAt
        }
        if let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            self.updatedAt = updatedAt
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(worshipHymnsHistory, forKey: .worshipHymnsHistory)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(modelVersion, forKey: .modelVersion)
    }
}

// MARK: - Extensions

extension WorshipService: Hashable {
    static func == (lhs: WorshipService, rhs: WorshipService) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension WorshipService {
    // MARK: - JSON Import/Export
    
    static func fromJSON(_ data: Data) -> WorshipService? {
        do {
            return try JSONDecoder().decode(WorshipService.self, from: data)
        } catch let error as DecodingError {
            print("WorshipService JSON decode error: \(error)")
            return nil
        } catch {
            print("WorshipService JSON decode error: \(error)")
            return nil
        }
    }
    
    func toJSON(pretty: Bool = false) -> Data? {
        do {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
            }
            return try encoder.encode(self)
        } catch let error as EncodingError {
            print("WorshipService JSON encode error: \(error)")
            return nil
        } catch {
            print("WorshipService JSON encode error: \(error)")
            return nil
        }
    }
    
    // MARK: - Batch JSON Import/Export
    
    static func arrayFromJSON(_ data: Data) -> [WorshipService]? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WorshipService].self, from: data)
        } catch let error as DecodingError {
            print("WorshipService array JSON decode error: \(error)")
            return nil
        } catch {
            print("WorshipService array JSON decode error: \(error)")
            return nil
        }
    }
    
    static func arrayToJSON(_ services: [WorshipService], pretty: Bool = false) -> Data? {
        do {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = .prettyPrinted
            }
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(services)
        } catch let error as EncodingError {
            print("WorshipService array JSON encode error: \(error)")
            return nil
        } catch {
            print("WorshipService array JSON encode error: \(error)")
            return nil
        }
    }
}