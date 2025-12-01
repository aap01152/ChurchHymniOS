//
//  ServiceHymn.swift
//  ChurchHymn
//
//  Created by paulo on 01/12/2025.
//

import SwiftUI
import SwiftData
import Foundation

@Model
class ServiceHymn: Identifiable, Codable, @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var hymnId: UUID
    var serviceId: UUID
    var order: Int
    var addedAt: Date
    var notes: String?
    var modelVersion: Int

    init(
        id: UUID = UUID(),
        hymnId: UUID,
        serviceId: UUID,
        order: Int,
        notes: String? = nil,
        modelVersion: Int = 1
    ) {
        self.id = id
        self.hymnId = hymnId
        self.serviceId = serviceId
        self.order = order
        self.addedAt = Date()
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelVersion = modelVersion
    }

    // MARK: - Helper Methods
    
    /// Update the order position
    func updateOrder(_ newOrder: Int) {
        self.order = newOrder
    }
    
    /// Add or update notes for this service hymn
    func updateNotes(_ newNotes: String?) {
        self.notes = newNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Migration Strategy
    // Use modelVersion to track schema changes
    // Future enhancements: custom transitions, key changes, special instructions

    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, hymnId, serviceId, order, addedAt, notes, modelVersion
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let hymnId = try container.decode(UUID.self, forKey: .hymnId)
        let serviceId = try container.decode(UUID.self, forKey: .serviceId)
        let order = try container.decode(Int.self, forKey: .order)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let modelVersion = try container.decodeIfPresent(Int.self, forKey: .modelVersion) ?? 1
        
        self.init(
            id: id,
            hymnId: hymnId,
            serviceId: serviceId,
            order: order,
            notes: notes,
            modelVersion: modelVersion
        )
        
        // Restore timestamp if available
        if let addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) {
            self.addedAt = addedAt
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hymnId, forKey: .hymnId)
        try container.encode(serviceId, forKey: .serviceId)
        try container.encode(order, forKey: .order)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(modelVersion, forKey: .modelVersion)
    }
}

// MARK: - Extensions

extension ServiceHymn: Hashable {
    static func == (lhs: ServiceHymn, rhs: ServiceHymn) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ServiceHymn {
    // MARK: - JSON Import/Export
    
    static func fromJSON(_ data: Data) -> ServiceHymn? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ServiceHymn.self, from: data)
        } catch let error as DecodingError {
            print("ServiceHymn JSON decode error: \(error)")
            return nil
        } catch {
            print("ServiceHymn JSON decode error: \(error)")
            return nil
        }
    }
    
    func toJSON(pretty: Bool = false) -> Data? {
        do {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = .prettyPrinted
            }
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(self)
        } catch let error as EncodingError {
            print("ServiceHymn JSON encode error: \(error)")
            return nil
        } catch {
            print("ServiceHymn JSON encode error: \(error)")
            return nil
        }
    }
    
    // MARK: - Batch JSON Import/Export
    
    static func arrayFromJSON(_ data: Data) -> [ServiceHymn]? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ServiceHymn].self, from: data)
        } catch let error as DecodingError {
            print("ServiceHymn array JSON decode error: \(error)")
            return nil
        } catch {
            print("ServiceHymn array JSON decode error: \(error)")
            return nil
        }
    }
    
    static func arrayToJSON(_ serviceHymns: [ServiceHymn], pretty: Bool = false) -> Data? {
        do {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = .prettyPrinted
            }
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(serviceHymns)
        } catch let error as EncodingError {
            print("ServiceHymn array JSON encode error: \(error)")
            return nil
        } catch {
            print("ServiceHymn array JSON encode error: \(error)")
            return nil
        }
    }
}

// MARK: - Service Hymn Operations Helper

extension ServiceHymn {
    /// Helper to create a new ServiceHymn with the next available order
    static func createForService(hymnId: UUID, serviceId: UUID, nextOrder: Int) -> ServiceHymn {
        return ServiceHymn(
            hymnId: hymnId,
            serviceId: serviceId,
            order: nextOrder
        )
    }
    
    /// Helper to check if this service hymn belongs to a specific service
    func belongsToService(_ serviceId: UUID) -> Bool {
        return self.serviceId == serviceId
    }
    
    /// Helper to check if this service hymn references a specific hymn
    func referencesHymn(_ hymnId: UUID) -> Bool {
        return self.hymnId == hymnId
    }
}