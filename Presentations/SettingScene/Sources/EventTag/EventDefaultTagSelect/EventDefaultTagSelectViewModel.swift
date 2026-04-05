//
//  
//  EventDefaultTagSelectViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - EventDefaultTagSelectViewModel

protocol EventDefaultTagSelectViewModel: AnyObject, Sendable, EventDefaultTagSelectSceneInteractor {

    // interactor
    func loadList()
    func select(_ tagId: EventTagId)
    func close()
    
    // presenter
    var cellViewModels: AnyPublisher<[BaseCalendarEventTagCellViewModel], Never> { get }
    var selectedId: AnyPublisher<EventTagId, Never> { get }
}


// MARK: - EventDefaultTagSelectViewModelImple

final class EventDefaultTagSelectViewModelImple: EventDefaultTagSelectViewModel, @unchecked Sendable {
    
    private let tagListUsecase: EventTagListViewUsecase
    private let settingUsecase: any EventSettingUsecase
    var router: (any EventDefaultTagSelectRouting)?
    
    init(
        tagUsecase: any EventTagUsecase,
        eventSettingUsecase: any EventSettingUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase
    ) {
        self.settingUsecase = eventSettingUsecase
        self.tagListUsecase = .init(
            tagUsecase: tagUsecase,
            googleCalendarUsecase: googleCalendarUsecase,
            appleCalendarUsecase: appleCalendarUsecase
        )
    }
    
    
    private struct Subject {
        let selectedId = CurrentValueSubject<EventTagId?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventDefaultTagSelectViewModelImple Interactor

extension EventDefaultTagSelectViewModelImple {
 
    func loadList() {
        self.tagListUsecase.reload()
        
        let setting = self.settingUsecase.loadEventSetting()
        self.subject.selectedId.send(setting.defaultNewEventTagId)
    }
    
    func select(_ tagId: EventTagId) {
        guard let old = self.subject.selectedId.value,
              old != tagId
        else { return }
        
        let params = EditEventSettingsParams()
            |> \.defaultNewEventTagId .~ tagId
        do {
            _ = try self.settingUsecase.changeEventSetting(params)
            self.subject.selectedId.send(tagId)
        } catch {
            self.router?.showError(error)
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - EventDefaultTagSelectViewModelImple Presenter

extension EventDefaultTagSelectViewModelImple {
    
    var cellViewModels: AnyPublisher<[BaseCalendarEventTagCellViewModel], Never> {
        let excludeHoliday: ([BaseCalendarEventTagCellViewModel]) -> [BaseCalendarEventTagCellViewModel] = { cvms in
            return cvms.filter { $0.id != .holiday }
        }
        return self.tagListUsecase.baseCalenadrCellViewModels
            .map(excludeHoliday)
            .eraseToAnyPublisher()
    }
    
    var selectedId: AnyPublisher<EventTagId, Never> {
        return self.subject.selectedId
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
