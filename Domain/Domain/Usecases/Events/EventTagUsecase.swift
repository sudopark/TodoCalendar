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

public protocol EventTagUsecase {
    
    func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag
    func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag
    
    func bindRefreshRequireTagInfos()
    func refreshTags(_ ids: [String])
    func eventTag(id: String) -> AnyPublisher<EventTag, Never>
    func eventTags(_ ids: [String]) -> AnyPublisher<[String: EventTag], Never>
}


public final class EventTagUsecaseImple: EventTagUsecase {
    
    private let tagRepository: EventTagRepository
    private let sharedDataStore: SharedDataStore
    private let refreshBindingQueue: DispatchQueue
    
    public init(
        tagRepository: EventTagRepository,
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
    
    private func updateSharedTags(_ tags: [EventTag]) {
        let newMap = tags.asDictionary { $0.uuid }
        self.sharedDataStore.update([String: EventTag].self, key: self.shareKey) {
            ($0 ?? [:]).merging(newMap) { $1 }
        }
    }
}

extension EventTagUsecaseImple {
    
    public func bindRefreshRequireTagInfos() {

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
