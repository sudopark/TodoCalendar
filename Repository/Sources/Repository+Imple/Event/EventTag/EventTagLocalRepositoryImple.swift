//
//  EventTagLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncFlatMap
import Domain
import Extensions


public final class EventTagLocalRepositoryImple: EventTagRepository {
    
    private let localStorage: any EventTagLocalStorage
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    
    private let environmentStorage: any EnvironmentStorage
    public init(
        localStorage: any EventTagLocalStorage,
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.localStorage = localStorage
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
        self.environmentStorage = environmentStorage
    }
}


extension EventTagLocalRepositoryImple {
    
    public func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let sameNameTags = try await self.localStorage.loadTag(match: params.name)
        guard sameNameTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        let tag = CustomEventTag(uuid: UUID().uuidString, name: params.name, colorHex: params.colorHex)
        try await self.localStorage.saveTag(tag)
        return tag
    }
    
    public func editTag(
        _ tagId: String,
        _ params: CustomEventTagEditParams
    ) async throws -> CustomEventTag {
        let sameNameOtherTags = try await self.localStorage.loadTag(match: params.name).filter { $0.uuid != tagId }
        guard sameNameOtherTags.isEmpty
        else {
            throw RuntimeError(key: "EvnetTag_Name_Duplicated", "event tag name:\(params.name) is already exists")
        }
        try await self.localStorage.editTag(tagId, with: params)
        return try await self.localStorage.loadTags(in: [tagId]).first.unwrap()
    }
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.localStorage.deleteTag(tagId)
        self.deleteOfftagId(tagId)
    }
    
    public func deleteTagWithAllEvents(_ tagId: String) async throws -> RemoveCustomEventTagWithEventsResult {
        
        try await self.deleteTag(tagId)
        let todoIds = try await self.todoLocalStorage.removeTodosWith(tagId: tagId)
        let scheduleIds = try await self.scheduleLocalStorage.removeSchedulesWith(tagId: tagId)
        return .init(todoIds: todoIds, scheduleIds: scheduleIds)
    }
}

extension EventTagLocalRepositoryImple {
    
    public func loadCustomTags(_ ids: [String]) -> AnyPublisher<[CustomEventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadTags(in: ids)
        }
        .eraseToAnyPublisher()
    }
    
    public func loadAllCustomTags() -> AnyPublisher<[CustomEventTag], any Error> {
        return Publishers.create { [weak self] in
            return try await self?.localStorage.loadAllTags()
        }
        .eraseToAnyPublisher()
    }
    
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
    
    private func deleteOfftagId(_ tagId: String) {
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
