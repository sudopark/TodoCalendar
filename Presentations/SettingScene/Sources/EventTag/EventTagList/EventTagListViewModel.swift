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
    
    private let eventTagListUsecase: EventTagListViewUsecase
    private let tagUsecase: EventTagUsecase
    var router: (any EventTagListRouting)?
    var listener: (any EventTagListSceneListener)?
    
    init(
        tagUsecase: EventTagUsecase
    ) {
        self.eventTagListUsecase = .init(tagUsecase: tagUsecase)
        self.tagUsecase = tagUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        let cvms = CurrentValueSubject<[EventTagCellViewModel]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBinding() {
        
        self.eventTagListUsecase.cellViewModels
            .sink(receiveValue: { [weak self] cvms in
                self?.subject.cvms.send(cvms)
            })
            .store(in: &self.cancellables)
        
        self.eventTagListUsecase.reloadFailed
            .sink(receiveValue: { [weak self] error in
                self?.router?.showError(error)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagListViewModelImple Interactor

extension EventTagListViewModelImple: EventTagDetailSceneListener {
    
    func reload() {
        
        self.eventTagListUsecase.reload()
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
            name: tagId == .holiday 
                ? "eventTag.defaults.holiday::name".localized()
                : "eventTag.defaults.default::name".localized(),
            color: tagId == .holiday ? .holiday : .default
        )
        self.router?.routeToEditTag(info, listener: self)
    }
    
    private func routeToCustomTagEdit(_ tagId: String) {
        guard let model = self.subject.cvms.value?.first(where: { $0.id.customTagId == tagId }),
              let customColor = model.color.customHex
        else { return }
        
        let info = OriginalTagInfo(
            id: .custom(tagId), name: model.name, color: .custom(hex: customColor)
        )
        self.router?.routeToEditTag(info, listener: self)
    }
    
    func eventTag(created newTag: EventTag) {
        let newModel = EventTagCellViewModel(
            id: .custom(newTag.uuid),
            name: newTag.name,
            color: .custom(hex: newTag.colorHex)
        )
        let newTags = [newModel] + (self.subject.cvms.value ?? [])
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(created: newTag)
    }
    
    func eventTag(updated newTag: EventTag) {
        let cvms = self.subject.cvms.value ?? []
        guard let index = cvms.firstIndex(where: { $0.id.customTagId == newTag.uuid })
        else { return }
        let newModel = EventTagCellViewModel(
            id: .custom(newTag.uuid),
            name: newTag.name,
            color: .custom(hex: newTag.colorHex)
        )
        let newTags = cvms |> ix(index) .~ newModel
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(updated: newTag)
    }
    
    func eventTag(deleted tagId: String) {
        let newTags = self.subject.cvms.value?.filter { $0.id.customTagId != tagId }
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(deleted: tagId)
    }
}


// MARK: - EventTagListViewModelImple Presenter

extension EventTagListViewModelImple {
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        return self.subject.cvms
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
