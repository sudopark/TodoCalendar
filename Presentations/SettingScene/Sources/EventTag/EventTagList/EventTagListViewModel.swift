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
    func toggleIsOn(_ tagId: EventTagId)
    func close()
    func addNewTag()
    func showTagDetail(_ tagId: EventTagId)
    func integrateCalendar(serviceId: String)
    
    // presenter
    var cellViewModels: AnyPublisher<[BaseCalendarEventTagCellViewModel], Never> { get }
    var externalCalendarSections: AnyPublisher<[ExternalCalendarEventTagListSectionModel], Never> { get }
}


// MARK: - EventTagListViewModelImple

final class EventTagListViewModelImple: EventTagListViewModel, @unchecked Sendable {
    
    private let eventTagListUsecase: EventTagListViewUsecase
    private let tagUsecase: EventTagUsecase
    var router: (any EventTagListRouting)?
    var listener: (any EventTagListSceneListener)?
    
    init(
        tagUsecase: any EventTagUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase
    ) {
        self.eventTagListUsecase = .init(
            tagUsecase: tagUsecase,
            googleCalendarUsecase: googleCalendarUsecase
        )
        self.tagUsecase = tagUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        let cvms = CurrentValueSubject<[BaseCalendarEventTagCellViewModel]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBinding() {
        
        self.eventTagListUsecase.baseCalenadrCellViewModels
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
        
        self.eventTagListUsecase.reloadExternalCalendarIfNeed()
    }
    
    func close() {
        self.router?.closeScene()
    }
    
    func addNewTag() {
        self.router?.routeToAddNewTag(listener: self)
    }
    
    func toggleIsOn(_ tagId: EventTagId) {
        self.tagUsecase.toggleEventTagIsOnCalendar(tagId)
    }
    
    func showTagDetail(_ tagId: EventTagId) {
        
        guard let model = self.subject.cvms.value?.first(where: { $0.id == tagId })
        else { return }
        
        let info = OriginalTagInfo(
            id: tagId,
            name: model.name,
            colorHex: model.colorHex
        )
        self.router?.routeToEditTag(info, listener: self)
    }
    
    func eventTag(created newTag: any EventTag) {
        let newModel = BaseCalendarEventTagCellViewModel(newTag)
        let newTags = [newModel] + (self.subject.cvms.value ?? [])
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(created: newTag)
    }
    
    func eventTag(updated newTag: any EventTag) {
        let cvms = self.subject.cvms.value ?? []
        guard let index = cvms.firstIndex(where: { $0.id == newTag.tagId })
        else { return }
        let newModel = BaseCalendarEventTagCellViewModel(newTag)
        let newTags = cvms |> ix(index) .~ newModel
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(updated: newTag)
    }
    
    func eventTag(deleted tagId: EventTagId) {
        let newTags = self.subject.cvms.value?.filter { $0.id != tagId }
        self.subject.cvms.send(newTags)
        self.listener?.eventTag(deleted: tagId)
    }
    
    func integrateCalendar(serviceId: String) {
        self.router?.routeToEventSetting()
    }
}


// MARK: - EventTagListViewModelImple Presenter

extension EventTagListViewModelImple {
    
    var cellViewModels: AnyPublisher<[BaseCalendarEventTagCellViewModel], Never> {
        return self.subject.cvms
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var externalCalendarSections: AnyPublisher<[ExternalCalendarEventTagListSectionModel], Never> {
        
        return self.eventTagListUsecase.externalCalendars
    }
}
