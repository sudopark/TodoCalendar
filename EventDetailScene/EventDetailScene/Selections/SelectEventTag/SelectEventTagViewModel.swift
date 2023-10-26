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
import Domain
import Scenes


struct TagCellViewModel: Equatable {
    let id: AllEventTagId
    let name: String
    let color: EventTagColor
    
    init(_ tag: EventTag) {
        self.id = .custom(tag.uuid)
        self.name = tag.name
        self.color = .custom(hex: tag.colorHex)
    }
    
    init(_ selectedTag: SelectedTag) {
        self.id = selectedTag.tagId
        self.name = selectedTag.name
        self.color = selectedTag.color
    }
}

// MARK: - SelectEventTagViewModel

protocol SelectEventTagViewModel: AnyObject, Sendable, SelectEventTagSceneInteractor {

    // interactor
    func refresh()
    func selectTag(_ id: AllEventTagId)
    func addTag()
    func moveToTagSetting()
    
    // presenter
    var selectedTagId: AnyPublisher<AllEventTagId, Never> { get }
    var tags: AnyPublisher<[TagCellViewModel], Never> { get }
}


// MARK: - SelectEventTagViewModelImple

final class SelectEventTagViewModelImple: SelectEventTagViewModel, @unchecked Sendable {
    
    private let tagUsecase: any EventTagUsecase
    var router: (any SelectEventTagRouting)?
    var listener: (any SelectEventTagSceneListener)?
    
    init(
        startWith initail: AllEventTagId,
        tagUsecase: any EventTagUsecase
    ) {
        
        self.tagUsecase = tagUsecase
        
        self.subject.selectedTagId.send(initail)
        
        self.bindSelectedTagNotify()
    }
    
    
    private struct Subject {
        let selectedTagId = CurrentValueSubject<AllEventTagId?, Never>(nil)
        let tags = CurrentValueSubject<[EventTag]?, Never>(nil)
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
    
    func refresh() {
        
        let loaded: ([EventTag]) -> Void = { [weak self] tags in
            self?.subject.tags.send(tags)
        }
        let handleError: (any Error) -> Void = { [weak self] error in
            self?.router?.showError(error)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: handleError)
            .store(in: &self.cancellables)
    }
    
    func selectTag(_ id: AllEventTagId) {
        self.subject.selectedTagId.send(id)
    }
    
    func addTag() {
        // TODO:
    }
    
    func moveToTagSetting() {
        // TODO:
    }
}


// MARK: - SelectEventTagViewModelImple Presenter

extension SelectEventTagViewModelImple {
    
    private var selectedTag: AnyPublisher<SelectedTag, Never> {
        let transform: ([EventTag], AllEventTagId) -> SelectedTag
        transform = { tags, selected in
            guard let customId = selected.customTagId 
            else {
                return selected == .holiday ? .holiday : .defaultTag
            }
            guard let selectedCustomTag = tags.first(where: { $0.uuid == customId })
            else {
                return .defaultTag
            }
            return .init(selectedCustomTag)
        }
        return Publishers.CombineLatest(
            self.subject.tags.compactMap { $0 },
            self.subject.selectedTagId.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var selectedTagId: AnyPublisher<AllEventTagId, Never> {
        
        return selectedTag
            .map { $0.tagId }
            .eraseToAnyPublisher()
    }
    
    var tags: AnyPublisher<[TagCellViewModel], Never> {
        let transform: ([EventTag]) -> [TagCellViewModel] = { tags in
            let defaultCVM = TagCellViewModel(.defaultTag)
            let holidayCVM = TagCellViewModel(.holiday)
            let cvms = tags.map { TagCellViewModel($0) }
            return [defaultCVM] + cvms + [holidayCVM]
        }
        return self.subject.tags
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

private extension AllEventTagId {
    
    var isCustom: Bool {
        guard case .custom = self else { return false }
        return true
    }
}
