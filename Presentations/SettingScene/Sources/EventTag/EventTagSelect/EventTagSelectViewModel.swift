//
//  
//  EventTagSelectViewModel.swift
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


// MARK: - EventTagSelectViewModel

protocol EventTagSelectViewModel: AnyObject, Sendable, EventTagSelectSceneInteractor {

    // interactor
    func loadList()
    func select(_ tagId: EventTagId)
    func close()
    
    // presenter
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> { get }
    var selectedId: AnyPublisher<EventTagId, Never> { get }
}


// MARK: - EventTagSelectViewModelImple

final class EventTagSelectViewModelImple: EventTagSelectViewModel, @unchecked Sendable {
    
    private let tagListUsecase: EventTagListViewUsecase
    private let settingUsecase: any EventSettingUsecase
    var router: (any EventTagSelectRouting)?
    
    init(
        tagUsecase: any EventTagUsecase,
        eventSettingUsecase: any EventSettingUsecase
    ) {
        self.settingUsecase = eventSettingUsecase
        self.tagListUsecase = .init(tagUsecase: tagUsecase)
    }
    
    
    private struct Subject {
        let selectedId = CurrentValueSubject<EventTagId?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventTagSelectViewModelImple Interactor

extension EventTagSelectViewModelImple {
 
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


// MARK: - EventTagSelectViewModelImple Presenter

extension EventTagSelectViewModelImple {
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        let excludeHoliday: ([EventTagCellViewModel]) -> [EventTagCellViewModel] = { cvms in
            return cvms.filter { $0.id != .holiday }
        }
        return self.tagListUsecase.cellViewModels
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
