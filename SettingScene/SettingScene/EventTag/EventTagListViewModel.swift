//
//  
//  EventTagListViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct EventTagCellViewModel: Equatable {
    
    var isOn: Bool = true
    let id: AllEventTagId
    let name: String
    let color: EventTagColor
}

// MARK: - EventTagListViewModel

protocol EventTagListViewModel: AnyObject, Sendable, EventTagListSceneInteractor {

    // interactor
    func reload()
    func toggleIsOn(_ tagId: AllEventTagId)
    func close()
    func addNewTag()
    func showTagDetail(_ tagId: AllEventTagId)
    
    // presenter
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> { get }
}


// MARK: - EventTagListViewModelImple

final class EventTagListViewModelImple: EventTagListViewModel, @unchecked Sendable {
    
    private let tagUsecase: EventTagUsecase
    var router: (any EventTagListRouting)?
    
    init(
        tagUsecase: EventTagUsecase
    ) {
        self.tagUsecase = tagUsecase
    }
    
    
    private struct Subject {
        let tags = CurrentValueSubject<[EventTag]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventTagListViewModelImple Interactor

extension EventTagListViewModelImple: EventTagDetailSceneListener {
    
    func reload() {
        
        let showError: (any Error) -> Void = { [weak self] error in
            self?.router?.showError(error)
        }
        let loaded: ([EventTag]) -> Void = { [weak self] tags in
            self?.subject.tags.send(tags)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: showError)
            .store(in: &self.cancellables)
    }
    
    func close() {
        self.router?.closeScene()
    }
    
    func addNewTag() {
        self.router?.routeToAddNewTag(listener: self)
    }
    
    func toggleIsOn(_ tagId: AllEventTagId) {
        self.tagUsecase.toggleEventTagIsOnCalendar(tagId)
    }
    
    func showTagDetail(_ tagId: AllEventTagId) {
        
        switch tagId {
        case .holiday, .default:
            self.routeToBaseTagEdit(tagId)
            
        case .custom(let id):
            self.routeToCustomTagEdit(id)
        }
    }
    
    private func routeToBaseTagEdit(_ tagId: AllEventTagId) {
        let info = OriginalTagInfo(
            id: tagId,
            name: tagId == .holiday ? "holiday".localized() : "default".localized(),
            color: tagId == .holiday ? .holiday : .default
        )
        self.router?.routeToEditTag(info, listener: self)
    }
    
    private func routeToCustomTagEdit(_ tagId: String) {
        guard let tag = self.subject.tags.value?.first(where: { $0.uuid == tagId })
        else { return }
        
        let info = OriginalTagInfo(
            id: .custom(tagId), name: tag.name, color: .custom(hex: tag.colorHex)
        )
        self.router?.routeToEditTag(info, listener: self)
    }
    
    func eventTag(created newTag: EventTag) {
        let newTags = [newTag] + (self.subject.tags.value ?? [])
        self.subject.tags.send(newTags)
    }
    
    func eventTag(updated newTag: EventTag) {
        let tags = self.subject.tags.value ?? []
        guard let index = tags.firstIndex(where: { $0.uuid == newTag.uuid })
        else { return }
        let newTags = tags |> ix(index) .~ newTag
        self.subject.tags.send(newTags)
    }
    
    func evetTag(deleted tagId: String) {
        let newTags = self.subject.tags.value?.filter { $0.uuid != tagId }
        self.subject.tags.send(newTags)
    }
}


// MARK: - EventTagListViewModelImple Presenter

extension EventTagListViewModelImple {
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        
        let asCellViewModels: ([EventTag]) -> [EventTagCellViewModel] = { tags in
            let holidayTag = EventTagCellViewModel(id: .holiday, name: "holiday".localized(), color: .holiday)
            let defaultTag = EventTagCellViewModel(id: .default, name: "default".localized(), color: .default)
            let customCells = tags.map {
                EventTagCellViewModel(
                    id: .custom($0.uuid),
                    name: $0.name,
                    color: .custom(hex: $0.colorHex)
                )
            }
            return [holidayTag, defaultTag] + customCells
        }
        let applyOnOff: ([EventTagCellViewModel], Set<AllEventTagId>) -> [EventTagCellViewModel] = { cvms, offTagIdSet in
            
            return cvms
                .map { $0 |> \.isOn .~ !offTagIdSet.contains($0.id) }
            
        }
        
        return Publishers.CombineLatest(
            self.subject.tags.compactMap { $0 }.map(asCellViewModels),
            self.tagUsecase.offEventTagIdsOnCalendar()
        )
        .map(applyOnOff)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
