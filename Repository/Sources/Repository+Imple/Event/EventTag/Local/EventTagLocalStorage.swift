//
//  EventTagLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
@preconcurrency import SQLiteService
import Domain
import Prelude
import Optics


public protocol EventTagLocalStorage: Sendable {
    func saveTag(_ tag: CustomEventTag) async throws
    func editTag(_ uuid: String, with params: CustomEventTagEditParams) async throws
    func updateTags(_ tags: [CustomEventTag]) async throws
    func deleteTags(_ tagIds: [String]) async throws
    func loadTag(match name: String) async throws -> [CustomEventTag]
    func loadTags(in ids: [String]) async throws -> [CustomEventTag]
    func loadAllTags() async throws -> [CustomEventTag]
    func removeAllTags() async throws
    
    func loadOffTags() -> Set<EventTagId>
    func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId>
    func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId>
    func deleteOfftagId(_ tagId: String)
    func resetExternalCalendarOffTagId(_ serviceId: String)
}
extension EventTagLocalStorage {
    
    func deleteTag(_ tagId: String) async throws {
        return try await deleteTags([tagId])
    }
    
    func loadTag(_ id: String) async throws -> CustomEventTag? {
        return try await self.loadTags(in: [id]).first
    }
}

public final class EventTagLocalStorageImple: EventTagLocalStorage {
    
    private let sqliteService: SQLiteService
    private let environmentStorage: any EnvironmentStorage
    public init(
        sqliteService: SQLiteService,
        environmentStorage: any EnvironmentStorage
    ) {
        self.sqliteService = sqliteService
        self.environmentStorage = environmentStorage
    }
    
    private typealias Tags = CustomEventTagTable
}


extension EventTagLocalStorageImple {
    
    public func saveTag(_ tag: CustomEventTag) async throws {
        try await self.sqliteService.async.run { db in
            try db.insertOne(Tags.self, entity: tag, shouldReplace: true)
        }
    }
    
    public func editTag(_ uuid: String, with params: CustomEventTagEditParams) async throws {
        try await self.sqliteService.async.run { db in
            let query = Tags.update {[
                $0.name == params.name,
                $0.colorHex == params.colorHex
            ]}
            .where { $0.uuid == uuid }
            try db.update(Tags.self, query: query)
        }
    }
    
    public func updateTags(_ tags: [CustomEventTag]) async throws {
        try await self.sqliteService.async.run { db in
            try db.insert(Tags.self, entities: tags)
        }
    }
    
    public func deleteTags(_ tagIds: [String]) async throws {
        try await self.sqliteService.async.run { db in
            let deleteQuery = Tags.delete().where { $0.uuid.in(tagIds) }
            try db.delete(Tags.self, query: deleteQuery)
        }
    }
    
    public func loadTag(match name: String) async throws -> [CustomEventTag] {
        let query = Tags.selectAll { $0.name == name }
        return try await self.sqliteService.async.run { try $0.load(query) }
    }
    
    public func loadTags(in ids: [String]) async throws -> [CustomEventTag] {
        let query = Tags.selectAll { $0.uuid.in(ids) }
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
    
    public func loadAllTags() async throws -> [CustomEventTag] {
        let query = Tags.selectAll()
        return try await self.sqliteService.async.run { db in
            return try db.load(Tags.self, query: query)
        }
    }
    
    public func removeAllTags() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(Tags.self) } 
    }
}

extension EventTagLocalStorageImple {
    
    private var offIds: String { "off_eventtagIds_on_calendar" }
    
    public func loadOffTags() -> Set<EventTagId> {
        let idStringValues: [String]? = self.environmentStorage.load(self.offIds)
        let ids = idStringValues?.compactMap { EventTagId($0) }
        return (ids ?? []) |> Set.init
    }
    
    public func toggleTagIsOn(_ tagId: EventTagId) -> Set<EventTagId> {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds |> elem(tagId) .~ !oldOffIds.contains(tagId)
        let newIdStringValues = newIds.map { $0.stringValue }
        self.environmentStorage.update(self.offIds, newIdStringValues)
        return newIds
    }
    
    public func addOffIds(_ ids: [EventTagId]) -> Set<EventTagId> {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds.union(ids)
        let newIdStringValue = newIds.map { $0.stringValue }
        self.environmentStorage.update(self.offIds, newIdStringValue)
        return newIds
    }
    
    public func deleteOfftagId(_ tagId: String) {
        let oldOffIds = self.loadOffTags()
        let newIds = oldOffIds |> elem(.custom(tagId)) .~ false
        let newIdStringValues = newIds.map { $0.stringValue }
        self.environmentStorage.update(self.offIds, newIdStringValues)
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        let newIds = self.loadOffTags().filter { $0.externalServiceId != serviceId }
        self.environmentStorage.update(self.offIds, newIds.map { $0.stringValue })
    }
}

extension EventTagId {
    
    var stringValue: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let id): return id
        case .externalCalendar(let serviceId, let id): return "external::\(serviceId)::\(id)"
        }
    }
    
    init?(_ stringValue: String) {
        switch stringValue {
        case "holiday": self = .holiday
        case "default": self = .default
        default:
            if stringValue.starts(with: "external:") {
                let compos = stringValue.components(separatedBy: "::")
                guard compos.count == 3 else { return nil }
                self = .externalCalendar(serviceId: compos[1], id: compos[2])
            } else {
                self = .custom(stringValue)
            }
        }
    }
}
