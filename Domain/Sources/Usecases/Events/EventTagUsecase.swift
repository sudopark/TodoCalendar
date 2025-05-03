//
//  EventTagUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


// MARK: - EventTagUsecase

public protocol EventTagUsecase: AnyObject, Sendable {
    
    func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag
    func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag
    func deleteTag(_ tagId: String) async throws
    func deleteTagWithAllEvents(_ tagId: String) async throws
    
    func prepare()
    func refreshCustomTags(_ ids: [String])
    func eventTag(id: EventTagId) -> AnyPublisher<any EventTag, Never>
    func eventTags(_ ids: [EventTagId]) -> AnyPublisher<[EventTagId: any EventTag], Never>
    func loadAllEventTags() -> AnyPublisher<[any EventTag], any Error>
    var sharedEventTags: AnyPublisher<[EventTagId: any EventTag], Never> { get }
    
    func toggleEventTagIsOnCalendar(_ tagId: EventTagId)
    func offEventTagIdsOnCalendar() -> AnyPublisher<Set<EventTagId>, Never>
    func resetExternalCalendarOffTagId(_ serviceId: String)
}


public final class EventTagUsecaseImple: EventTagUsecase, @unchecked Sendable {
    
    private let tagRepository: any EventTagRepository
    private let todoEventusecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let sharedDataStore: SharedDataStore
    private let refreshBindingQueue: DispatchQueue
    
    public init(
        tagRepository: any EventTagRepository,
        todoEventusecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        sharedDataStore: SharedDataStore,
        refreshBindingQueue: DispatchQueue? = nil
    ) {
        self.tagRepository = tagRepository
        self.todoEventusecase = todoEventusecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.sharedDataStore = sharedDataStore
        self.refreshBindingQueue = refreshBindingQueue ?? DispatchQueue(label: "event-tag-binding")
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var shareKey: String { ShareDataKeys.tags.rawValue }
}


// MARK: - make and edit

extension EventTagUsecaseImple {
    
    public func makeNewTag(_ params: CustomEventTagMakeParams) async throws -> CustomEventTag {
        let tag = try await self.tagRepository.makeNewTag(params)
        self.updateSharedTags([tag])
        return tag
    }
    
    public func editTag(_ tagId: String, _ params: CustomEventTagEditParams) async throws -> CustomEventTag {
        let updated = try await self.tagRepository.editTag(tagId, params)
        self.updateSharedTags([updated])
        return updated
    }
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.tagRepository.deleteTag(tagId)
        self.handleTagDeleted(tagId)
    }
    
    public func deleteTagWithAllEvents(_ tagId: String) async throws {
        let result = try await self.tagRepository.deleteTagWithAllEvents(tagId)
        self.handleTagDeleted(tagId)
        self.todoEventusecase.handleRemovedTodos(result.todoIds)
        self.scheduleEventUsecase.handleRemovedSchedules(result.scheduleIds)
    }
    
    private func handleTagDeleted(_ tagId: String) {
        self.sharedDataStore.update([EventTagId: any EventTag].self, key: self.shareKey) {
            ($0 ?? [:]) |> key(.custom(tagId)) .~ nil
        }
        self.sharedDataStore.update(Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue) {
            ($0 ?? []) |> elem(.custom(tagId)) .~ false
        }
    }
    
    private func updateSharedTags(_ tags: [CustomEventTag]) {
        let newMap = tags.asDictionary { $0.tagId }
        self.sharedDataStore.update([EventTagId: any EventTag].self, key: self.shareKey) {
            ($0 ?? [:]).merging(newMap) { $1 }
        }
    }
}

extension EventTagUsecaseImple {
    
    public func prepare() {
        self.bindDefaultTags()
        self.bindRefreshRequireTagInfos()
    }
    
    private func bindRefreshRequireTagInfos() {

        let (todoKey, scheduleKey) = (ShareDataKeys.todos.rawValue, ShareDataKeys.schedules.rawValue)
        let allTagIdsFromTodos = self.sharedDataStore.observe([String: TodoEvent].self, key: todoKey)
            .map { $0.flatMap { Array($0.values)} ?? [] }
            .map { ts in ts.compactMap { $0.eventTagId?.customTagId } }
            .map { Set($0) }
        let allTagIdsSchedules = self.sharedDataStore.observe(MemorizedEventsContainer<ScheduleEvent>.self, key: scheduleKey)
            .map { $0?.allCachedEvents() ?? []}
            .map { ss in ss.compactMap { $0.eventTagId?.customTagId } }
            .map { Set($0) }
        
        // TODO: 완료되지않은 할일 tag도 합성 필요
        
        let refreshNeedTagIds = Publishers.CombineLatest(allTagIdsFromTodos, allTagIdsSchedules)
            .map { $0.0.union($0.1 ) }
            .scan(AllTagIds.empty) { $0.updated($1) }
            .map { $0.newIds }
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .map { Array($0) }
        
        refreshNeedTagIds
            .subscribe(on: self.refreshBindingQueue)
            .sink(receiveValue: { [weak self] ids in
                self?.refreshCustomTags(ids)
            })
            .store(in: &self.cancellables)
        
        let offIds = self.tagRepository.loadOffTags()
        self.sharedDataStore.put(Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, offIds)
    }
    
    private func bindDefaultTags() {
        let key = self.shareKey
        let updateStore: ([EventTagId: DefaultEventTag]) -> Void = { [weak self] defs in
            self?.sharedDataStore.update([EventTagId: any EventTag].self, key: key) {
                ($0 ?? [:]).merging(defs) { $1 }
            }
        }
        
        self.defaultTags
            .removeDuplicates()
            .map { $0.asDictionary { $0.tagId }}
            .sink(receiveValue: updateStore)
            .store(in: &self.cancellables)
    }
    
    public func refreshCustomTags(_ ids: [String]) {
        
        let shareKey = self.shareKey
        let updateCached: ([CustomEventTag]) -> Void = { [weak self] tags in
            let newMap = tags.reduce(into: [EventTagId: any EventTag]()) { acc, tag in
                acc[.custom(tag.uuid)] = tag
            }
            self?.sharedDataStore.update([EventTagId: any EventTag].self, key: shareKey) {
                ($0 ?? [:]).merging(newMap) { $1 }
            }
        }
        
        self.tagRepository.loadCustomTags(ids)
            .sink(receiveCompletion: { _ in }, receiveValue: updateCached)
            .store(in: &self.cancellables)
    }
    
    public func eventTag(id: EventTagId) -> AnyPublisher<any EventTag, Never> {
        return self.sharedDataStore.observe([EventTagId: any EventTag].self, key: self.shareKey)
            .compactMap { $0?[id] }
            .eraseToAnyPublisher()
    }
    
    public func eventTags(_ ids: [EventTagId]) -> AnyPublisher<[EventTagId : any EventTag], Never> {
        
        let idsSet = Set(ids)
        return self.sharedDataStore.observe([EventTagId: any EventTag].self, key: self.shareKey)
            .map { tagMap in
                return (tagMap ?? [:]).filter { idsSet.contains($0.key) }
            }
            .eraseToAnyPublisher()
    }
    
    public func loadAllEventTags() -> AnyPublisher<[any EventTag], any Error> {
        let key = self.shareKey
        let updateCached: ([CustomEventTag]) -> Void = { [weak self] tags in
            let newMap = tags.asDictionary { $0.tagId }.mapValues { $0 as any EventTag }
            self?.sharedDataStore.update([EventTagId: any EventTag].self, key: key) { oldMap in
                let defs = (oldMap ?? [:]).filter { $0.key == .default || $0.key == .holiday }
                let combined = newMap.merging(defs) { c, _ in c  }
                return combined
            }
        }
        
        let loadAllCustomTagsWithUpdateCache = self.tagRepository.loadAllCustomTags()
            .handleEvents(receiveOutput: updateCached)
            .map { $0 as [any EventTag] }
        
        typealias Pair = ([any EventTag], [DefaultEventTag])
        return loadAllCustomTagsWithUpdateCache
            .compactMap { [weak self] customs in
                return self?.defaultTags.map { Pair(customs, $0) }
            }
            .switchToLatest()
            .map { $0.0 + $0.1 }
            .eraseToAnyPublisher()
    }
    
    public var sharedEventTags: AnyPublisher<[EventTagId: any EventTag], Never> {
        return self.sharedDataStore.observe([EventTagId: any EventTag].self, key: self.shareKey)
            .map { $0 ?? [:] }
            .eraseToAnyPublisher()
    }
    
    private var defaultTags: AnyPublisher<[DefaultEventTag], Never> {
        return self.sharedDataStore.observe(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue
        )
        .map { setting in
            return setting.map { [DefaultEventTag.default($0.default), .holiday($0.holiday)] } ?? []
        }
        .eraseToAnyPublisher()
    }
}

extension EventTagUsecaseImple {
    
    public func toggleEventTagIsOnCalendar(_ tagId: EventTagId) {
        let newSet = self.tagRepository.toggleTagIsOn(tagId)
        self.sharedDataStore.put(Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, newSet)
    }
    
    public func offEventTagIdsOnCalendar() -> AnyPublisher<Set<EventTagId>, Never> {
        return self.sharedDataStore
            .observe(Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue)
            .map { $0 ?? [] }
            .eraseToAnyPublisher()
    }
    
    public func resetExternalCalendarOffTagId(_ serviceId: String) {
        self.tagRepository.resetExternalCalendarOffTagId(serviceId)
        self.sharedDataStore.update(
            Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue
        ) { old in
            return (old ?? []).filter { $0.externalServiceId != serviceId }
        }
    }
}

private struct AllTagIds {
    
    private let totalIdSet: Set<String>
    let newIds: Set<String>
    
    static var empty: AllTagIds {
        return .init(totalIdSet: [], newIds: [])
    }
    
    func updated(_ newSet: Set<String>) -> AllTagIds {
        let newIds = newSet.subtracting(self.totalIdSet)
        return .init(totalIdSet: self.totalIdSet.union(newSet), newIds: newIds)
    }
}
