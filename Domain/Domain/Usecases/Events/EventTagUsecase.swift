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

public protocol EventTagUsecase: Sendable {
    
    func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag
    func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag
    func deleteTag(_ tagId: String) async throws
    
    func prepare()
    func refreshTags(_ ids: [String])
    func eventTag(id: String) -> AnyPublisher<EventTag, Never>
    func eventTags(_ ids: [String]) -> AnyPublisher<[String: EventTag], Never>
    func loadAllEventTags() -> AnyPublisher<[EventTag], any Error>
    var latestUsedEventTag: AnyPublisher<EventTag?, Never> { get }
    
    func toggleEventTagIsOnCalendar(_ tagId: AllEventTagId)
    func offEventTagIdsOnCalendar() -> AnyPublisher<Set<AllEventTagId>, Never>
}


public final class EventTagUsecaseImple: EventTagUsecase, @unchecked Sendable {
    
    private let tagRepository: any EventTagRepository
    private let sharedDataStore: SharedDataStore
    private let refreshBindingQueue: DispatchQueue
    
    public init(
        tagRepository: any EventTagRepository,
        sharedDataStore: SharedDataStore,
        refreshBindingQueue: DispatchQueue? = nil
    ) {
        self.tagRepository = tagRepository
        self.sharedDataStore = sharedDataStore
        self.refreshBindingQueue = refreshBindingQueue ?? DispatchQueue(label: "event-tag-binding")
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var shareKey: String { ShareDataKeys.tags.rawValue }
}


// MARK: - make and edit

extension EventTagUsecaseImple {
    
    public func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag {
        let tag = try await self.tagRepository.makeNewTag(params)
        self.updateSharedTags([tag])
        return tag
    }
    
    public func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag {
        let updated = try await self.tagRepository.editTag(tagId, params)
        self.updateSharedTags([updated])
        return updated
    }
    
    public func deleteTag(_ tagId: String) async throws {
        try await self.tagRepository.deleteTag(tagId)
        self.sharedDataStore.update([String: EventTag].self, key: self.shareKey) {
            ($0 ?? [:]) |> key(tagId) .~ nil
        }
        self.sharedDataStore.update(Set<AllEventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue) {
            ($0 ?? []) |> elem(.custom(tagId)) .~ false
        }
    }
    
    private func updateSharedTags(_ tags: [EventTag]) {
        let newMap = tags.asDictionary { $0.uuid }
        self.sharedDataStore.update([String: EventTag].self, key: self.shareKey) {
            ($0 ?? [:]).merging(newMap) { $1 }
        }
    }
}

extension EventTagUsecaseImple {
    
    public func prepare() {
        self.loadAndUpdateLatestUsedTag()
        self.bindRefreshRequireTagInfos()
    }
    
    private func loadAndUpdateLatestUsedTag() {
        Task { [weak self] in
            let key = ShareDataKeys.latestUsedEventTag.rawValue
            if let tag = try await self?.tagRepository.loadLatestUsedTag() {
                self?.sharedDataStore.put(EventTag.self, key: key, tag)
            } else {
                self?.sharedDataStore.delete(key)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func bindRefreshRequireTagInfos() {

        let (todoKey, scheduleKey) = (ShareDataKeys.todos.rawValue, ShareDataKeys.schedules.rawValue)
        let allTagIdsFromTodos = self.sharedDataStore.observe([String: TodoEvent].self, key: todoKey)
            .map { $0.flatMap { Array($0.values)} ?? [] }
            .map { ts in ts.compactMap { $0.eventTagId } }
            .map { Set($0) }
        let allTagIdsSchedules = self.sharedDataStore.observe(MemorizedScheduleEventsContainer.self, key: scheduleKey)
            .map { $0?.allCachedEvents() ?? []}
            .map { ss in ss.compactMap { $0.eventTagId } }
            .map { Set($0) }
        
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
                self?.refreshTags(ids)
            })
            .store(in: &self.cancellables)
        
        let offIds = self.tagRepository.loadOffTags()
        self.sharedDataStore.put(Set<AllEventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, offIds)
    }
    
    public func refreshTags(_ ids: [String]) {
        
        let shareKey = self.shareKey
        let updateCached: ([EventTag]) -> Void = { [weak self] tags in
            let newMap = tags.asDictionary { $0.uuid }
            self?.sharedDataStore.update([String: EventTag].self, key: shareKey) {
                ($0 ?? [:]).merging(newMap) { $1 }
            }
        }
        
        self.tagRepository.loadTags(ids)
            .sink(receiveCompletion: { _ in }, receiveValue: updateCached)
            .store(in: &self.cancellables)
    }
    
    public func eventTag(id: String) -> AnyPublisher<EventTag, Never> {
        return self.sharedDataStore.observe([String: EventTag].self, key: self.shareKey)
            .compactMap { $0?[id] }
            .eraseToAnyPublisher()
    }
    
    public func eventTags(_ ids: [String]) -> AnyPublisher<[String : EventTag], Never> {
        let idsSet = Set(ids)
        return self.sharedDataStore.observe([String: EventTag].self, key: self.shareKey)
            .map { tagMap in
                return (tagMap ?? [:]).filter { idsSet.contains($0.key) }
            }
            .eraseToAnyPublisher()
    }
    
    public func loadAllEventTags() -> AnyPublisher<[EventTag], any Error> {
        let updateCached: ([EventTag]) -> Void = { [weak self] tags in
            let newMap = tags.asDictionary { $0.uuid }
            self?.sharedDataStore.put(
                [String: EventTag].self,
                key: ShareDataKeys.tags.rawValue,
                newMap
            )
        }
        return self.tagRepository.loadAllTags()
            .handleEvents(receiveOutput: updateCached)
            .eraseToAnyPublisher()
    }
    
    public var latestUsedEventTag: AnyPublisher<EventTag?, Never> {
        
        return self.sharedDataStore
            .observe(EventTag.self, key: ShareDataKeys.latestUsedEventTag.rawValue)
    }
}

extension EventTagUsecaseImple {
    
    public func toggleEventTagIsOnCalendar(_ tagId: AllEventTagId) {
        let newSet = self.tagRepository.toggleTagIsOn(tagId)
        self.sharedDataStore.put(Set<AllEventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, newSet)
    }
    
    public func offEventTagIdsOnCalendar() -> AnyPublisher<Set<AllEventTagId>, Never> {
        return self.sharedDataStore
            .observe(Set<AllEventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue)
            .map { $0 ?? [] }
            .eraseToAnyPublisher()
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
