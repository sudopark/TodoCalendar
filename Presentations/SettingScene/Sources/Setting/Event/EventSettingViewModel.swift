//
//  
//  EventSettingViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct SelectedPeriodModel: Equatable {
    let period: EventSettings.DefaultNewEventPeriod
    let text: String
    
    init(_ period: EventSettings.DefaultNewEventPeriod) {
        self.period = period
        self.text = switch period {
        case .minute0: "%d minutes".localized(with: 0)
        case .minute5: "%d minutes".localized(with: 5)
        case .minute10: "%d minutes".localized(with: 10)
        case .minute15: "%d minutes".localized(with: 15)
        case .minute30: "%d minutes".localized(with: 30)
        case .minute45: "%d minutes".localized(with: 45)
        case .hour1: "%d hours".localized(with: 1)
        case .hour2: "%d hours".localized(with: 2)
        case .allDay: "Allday".localized()
        }
    }
}

// MARK: - EventSettingViewModel

protocol EventSettingViewModel: AnyObject, Sendable, EventSettingSceneInteractor {

    // interactor
    func prepare()
    func selectTag()
    func selectPeriod(_ newValue: EventSettings.DefaultNewEventPeriod)
    func close()
    
    // presenter
    var selectedTagModel: AnyPublisher<EventTagCellViewModel, Never> { get }
    var selectedPeriod: AnyPublisher<SelectedPeriodModel, Never> { get }
}


// MARK: - EventSettingViewModelImple

final class EventSettingViewModelImple: EventSettingViewModel, @unchecked Sendable {
    
    private let eventSettingUsecase: any EventSettingUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any EventSettingRouting)?
    
    init(
        eventSettingUsecase: any EventSettingUsecase,
        eventTagUsecase: any EventTagUsecase
    ) {
        self.eventSettingUsecase = eventSettingUsecase
        self.eventTagUsecase = eventTagUsecase
        
    }
    
    
    private struct Subject {
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventSettingViewModelImple Interactor

extension EventSettingViewModelImple {
    
    func prepare() {
        _ = self.eventSettingUsecase.loadEventSetting()
    }
 
    func selectTag() {
        self.router?.routeToSelectTag()
    }
    
    func selectPeriod(_ newValue: EventSettings.DefaultNewEventPeriod) {
        let params = EditEventSettingsParams()
            |> \.defaultNewEventPeriod .~ newValue
        do {
            _ = try self.eventSettingUsecase.changeEventSetting(params)
        } catch {
            self.router?.showError(error)
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - EventSettingViewModelImple Presenter

extension EventSettingViewModelImple {
    
    var selectedTagModel: AnyPublisher<EventTagCellViewModel, Never> {
        let asEventTag: (AllEventTagId) -> AnyPublisher<EventTagCellViewModel, Never> = { [weak self] id in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            switch id {
            case .holiday: 
                return Just(EventTagCellViewModel.holiday).eraseToAnyPublisher()
                
            case .default:
                return Just(EventTagCellViewModel.default).eraseToAnyPublisher()
                
            case .custom(let value):
                return self.eventTagUsecase.eventTag(id: value)
                    .map { t -> EventTagCellViewModel in
                        return .init(id: .custom(t.uuid), name: t.name, color: .custom(hex: t.colorHex))
                    }
                    .eraseToAnyPublisher()
            }
        }
        
        return self.eventSettingUsecase.currentEventSetting
            .map { $0.defaultNewEventTagId }
            .map(asEventTag)
            .switchToLatest()
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedPeriod: AnyPublisher<SelectedPeriodModel, Never> {
        
        return self.eventSettingUsecase.currentEventSetting
            .map { $0.defaultNewEventPeriod }
            .map { SelectedPeriodModel($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
