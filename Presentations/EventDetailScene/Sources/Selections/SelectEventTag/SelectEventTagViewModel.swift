//
//  
//  SelectEventTagViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct TagCellViewModel: Equatable {
    let id: EventTagId
    let name: String
    let colorHex: String
    
    init(_ tag: any EventTag) {
        self.id = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
    
    init(_ selectedTag: SelectedTag) {
        self.id = selectedTag.tagId
        self.name = selectedTag.name
        self.colorHex = selectedTag.colorHex
    }
}

// MARK: - SelectEventTagViewModel

protocol SelectEventTagViewModel: AnyObject, Sendable, SelectEventTagSceneInteractor {

    // interactor
    func close()
    func refresh()
    func selectTag(_ id: EventTagId)
    func addTag()
    func moveToTagSetting()
    
    // presenter
    var selectedTagId: AnyPublisher<EventTagId, Never> { get }
    var tags: AnyPublisher<[TagCellViewModel], Never> { get }
}


// MARK: - SelectEventTagViewModelImple

final class SelectEventTagViewModelImple: SelectEventTagViewModel, @unchecked Sendable {
    
    private let tagUsecase: any EventTagUsecase
    var router: (any SelectEventTagRouting)?
    var listener: (any SelectEventTagSceneListener)?
    
    init(
        startWith initail: EventTagId,
        tagUsecase: any EventTagUsecase
    ) {
        
        self.tagUsecase = tagUsecase
        
        self.subject.selectedTagId.send(initail)
        
        self.bindSelectedTagNotify()
    }
    
    
    private struct Subject {
        let selectedTagId = CurrentValueSubject<EventTagId?, Never>(nil)
        let tags = CurrentValueSubject<[any EventTag]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func bindSelectedTagNotify() {
        
        self.selectedTag
            .dropFirst()
            .sink(receiveValue: { [weak self] tag in
                self?.listener?.selectEventTag(didSelected: tag)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - SelectEventTagViewModelImple Interactor

extension SelectEventTagViewModelImple {
    
    func close() {
        self.router?.closeScene(animate: true, nil)
    }
    
    // TODO: view에서 호출시에 최초 1회만 하도록, listener로 태그 리스트 변경 받은 경우에 명시적으로 refresh 예정
    func refresh() {
        
        let loaded: ([any EventTag]) -> Void = { [weak self] tags in
            self?.subject.tags.send(tags)
        }
        let handleError: (any Error) -> Void = { [weak self] error in
            self?.router?.showError(error)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: handleError)
            .store(in: &self.cancellables)
    }
    
    func selectTag(_ id: EventTagId) {
        self.subject.selectedTagId.send(id)
    }
    
    func addTag() {
        self.router?.routeToAddNewTagScene()
    }
    
    func moveToTagSetting() {
        self.router?.routeToTagListScene()
    }
    
    func eventTag(created newTag: any EventTag) {
        defer {
            self.subject.selectedTagId.send(newTag.tagId)
        }
        let tags = self.subject.tags.value ?? []
        guard !tags.contains(where: { $0.tagId == newTag.tagId }) else { return }
        let newTags = [newTag] + tags
        self.subject.tags.send(newTags)
    }
    
    func eventTag(updated newTag: any EventTag) {
        guard let tags = self.subject.tags.value,
              let index = tags.firstIndex(where: { $0.tagId == newTag.tagId })
        else { return }
        let newTags = tags |> ix(index) .~ newTag
        self.subject.tags.send(newTags)
    }
    
    func eventTag(deleted tagId: EventTagId) {
        let newTags = self.subject.tags.value?.filter { $0.tagId != tagId }
        self.subject.tags.send(newTags)
    }
}


// MARK: - SelectEventTagViewModelImple Presenter

extension SelectEventTagViewModelImple {
    
    private var selectedTag: AnyPublisher<SelectedTag, Never> {
        let transform: ([any EventTag], EventTagId) -> SelectedTag?
        transform = { tags, selected in
            guard let selectedTag = tags.first(where: { $0.tagId == selected })
            else {
                return tags.first(where: { $0.tagId == .default })
                    .map { .init($0) }
            }
            return .init(selectedTag)
        }
        return Publishers.CombineLatest(
            self.subject.tags.compactMap { $0 },
            self.subject.selectedTagId.compactMap { $0 }
        )
        .compactMap(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedTagId: AnyPublisher<EventTagId, Never> {
        
        return selectedTag
            .map { $0.tagId }
            .eraseToAnyPublisher()
    }
    
    var tags: AnyPublisher<[TagCellViewModel], Never> {
        let transform: ([any EventTag]) -> [TagCellViewModel] = { tags in
            let tagsWithoutHoliday = tags.filter { $0.tagId != .holiday }
            return tagsWithoutHoliday
                .sortDefaultTagsAtFirst()
                .map{ .init($0) }
        }
        return self.subject.tags
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
