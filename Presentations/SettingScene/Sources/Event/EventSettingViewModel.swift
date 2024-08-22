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


struct SelectedPeriodModel: Hashable {
    let period: EventSettings.DefaultNewEventPeriod
    let text: String
    
    init(_ period: EventSettings.DefaultNewEventPeriod) {
        self.period = period
        self.text = switch period {
        case .minute0: "calendar::event_time::period:some_minutes".localized(with: 0)
        case .minute5: "calendar::event_time::period:some_minutes".localized(with: 5)
        case .minute10: "calendar::event_time::period:some_minutes".localized(with: 10)
        case .minute15: "calendar::event_time::period:some_minutes".localized(with: 15)
        case .minute30: "calendar::event_time::period:some_minutes".localized(with: 30)
        case .minute45: "calendar::event_time::period:some_minutes".localized(with: 45)
        case .hour1: "calendar::event_time::period:some_hours".localized(with: 1)
        case .hour2: "calendar::event_time::period:some_hours".localized(with: 2)
        case .allDay: "calendar::event_time::allday".localized()
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(period.rawValue)
    }
}

// MARK: - EventSettingViewModel

protocol EventSettingViewModel: AnyObject, Sendable, EventSettingSceneInteractor {

    // interactor
    func prepare()
    func reloadEventNotificationSetting()
    func selectTag()
    func selectEventNotificationTimeOption(forAllDay: Bool)
    func selectPeriod(_ newValue: EventSettings.DefaultNewEventPeriod)
    func close()
    
    // presenter
    var selectedTagModel: AnyPublisher<EventTagCellViewModel, Never> { get }
    var selectedEventNotificationTimeText: AnyPublisher<String, Never> { get }
    var selectedAllDayEventNotificationTimeText: AnyPublisher<String, Never> { get }
    var selectedPeriod: AnyPublisher<SelectedPeriodModel, Never> { get }
}


// MARK: - EventSettingViewModelImple

final class EventSettingViewModelImple: EventSettingViewModel, @unchecked Sendable {
    
    private let eventSettingUsecase: any EventSettingUsecase
    private let eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any EventSettingRouting)?
    
    init(
        eventSettingUsecase: any EventSettingUsecase,
        eventNotificationSettingUsecase: any EventNotificationSettingUsecase,
        eventTagUsecase: any EventTagUsecase
    ) {
        self.eventSettingUsecase = eventSettingUsecase
        self.eventNotificationSettingUsecase = eventNotificationSettingUsecase
        self.eventTagUsecase = eventTagUsecase
     
        self.internalBinding()
    }
    
    
    private struct Subject {
        let setting = CurrentValueSubject<EventSettings?, Never>(nil)
        let eventNotificationTimeOption = CurrentValueSubject<EventNotificationTimeOption??, Never>(nil)
        let allDayEventNotificationTimeOption = CurrentValueSubject<EventNotificationTimeOption??, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBinding() {
        
        self.eventSettingUsecase.currentEventSetting
            .sink(receiveValue: { [weak self] setting in
                self?.subject.setting.send(setting)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventSettingViewModelImple Interactor

extension EventSettingViewModelImple {
    
    func prepare() {
        let setting = self.eventSettingUsecase.loadEventSetting()
        self.subject.setting.send(setting)
    }
    
    func reloadEventNotificationSetting() {
        let option = self.eventNotificationSettingUsecase.loadDefailtNotificationTimeOption(forAllDay: false)
        self.subject.eventNotificationTimeOption.send(option)
        
        let optionForAllDay = self.eventNotificationSettingUsecase.loadDefailtNotificationTimeOption(forAllDay: true)
        self.subject.allDayEventNotificationTimeOption.send(optionForAllDay)
    }
 
    func selectTag() {
        self.router?.routeToSelectTag()
    }
    
    func selectEventNotificationTimeOption(forAllDay: Bool) {
        self.router?.routeToEventNotificationTime(forAllDay: forAllDay)
    }
    
    func selectPeriod(_ newValue: EventSettings.DefaultNewEventPeriod) {
        guard let setting = self.subject.setting.value,
              setting.defaultNewEventPeriod != newValue
        else { return }
        
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
    
    private func optionsText() -> (EventNotificationTimeOption?) -> String {
        return { option in
            return DefaultTimeOptionModel(option: option).text
        }
    }
    
    var selectedEventNotificationTimeText: AnyPublisher<String, Never> {
        return self.subject.eventNotificationTimeOption
            .compactMap { $0 }
            .map(self.optionsText())
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedAllDayEventNotificationTimeText: AnyPublisher<String, Never> {
        return self.subject.allDayEventNotificationTimeOption
            .compactMap { $0 }
            .map(self.optionsText())
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
