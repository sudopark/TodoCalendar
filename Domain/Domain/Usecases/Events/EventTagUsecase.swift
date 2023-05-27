//
//  EventTagUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Combine
import Extensions


// MARK: - EventTagUsecase

public protocol EventTagUsecase {
    
    func makeNewTag(_ params: EventTagMakeParams) async throws -> EventTag
    func editTag(_ tagId: String, _ params: EventTagEditParams) async throws -> EventTag
    
    func refreshTags(_ ids: [String])
    func eventTags(_ ids: [String]) -> AnyPublisher<[String: EventTag], Never>
}


public final class EventTagUsecaseImple: EventTagUsecase {
    
    private let tagRepository: EventTagRepository
    private let sharedDataStore: SharedDataStore
    
    public init(
        tagRepository: EventTagRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.tagRepository = tagRepository
        self.sharedDataStore = sharedDataStore
    }
    
    private var cancellables: Set<AnyCancellable> = []
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
        let shareKey = ShareDataKeys.tags.rawValue
        let newMap = tags.asDictionary { $0.uuid }
        self.sharedDataStore.update([String: EventTag].self, key: shareKey) {
            ($0 ?? [:]).merging(newMap) { $1 }
        }
    }
}

extension EventTagUsecaseImple {
    
    public func refreshTags(_ ids: [String]) {
        
        let updateCached: ([EventTag]) -> Void = { [weak self] tags in
            let shareKey = ShareDataKeys.tags.rawValue
            let newMap = tags.asDictionary { $0.uuid }
            self?.sharedDataStore.update([String: EventTag].self, key: shareKey) {
                ($0 ?? [:]).merging(newMap) { $1 }
            }
        }
        
        self.tagRepository.loadTags(ids)
            .sink(receiveCompletion: { _ in }, receiveValue: updateCached)
            .store(in: &self.cancellables)
    }
    
    public func eventTags(_ ids: [String]) -> AnyPublisher<[String : EventTag], Never> {
        let shareKey = ShareDataKeys.tags.rawValue
        let idsSet = Set(ids)
        return self.sharedDataStore.observe([String: EventTag].self, key: shareKey)
            .map { tagMap in
                return (tagMap ?? [:]).filter { idsSet.contains($0.key) }
            }
            .eraseToAnyPublisher()
    }
}
