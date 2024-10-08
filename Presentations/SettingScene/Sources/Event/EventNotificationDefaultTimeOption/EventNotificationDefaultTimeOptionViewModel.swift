//
//  
//  EventNotificationDefaultTimeOptionViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes
import CommonPresentation


// MARK: - EventNotificationDefaultTimeOptionViewModel

struct DefaultTimeOptionModel: Equatable {
    let text: String
    let option: EventNotificationTimeOption?
    
    init(option: EventNotificationTimeOption?) {
        self.option = option
        self.text = option.text
    }
}

protocol EventNotificationDefaultTimeOptionViewModel: AnyObject, Sendable, EventNotificationDefaultTimeOptionSceneInteractor {

    // interactor
    func reload()
    func requestPermission()
    func selectOption(_ option: EventNotificationTimeOption?)
    func close()
    
    // presenter
    var forAllDay:Bool { get }
    var isNeedNotificationPermission: AnyPublisher<Bool, Never> { get }
    var options: AnyPublisher<[DefaultTimeOptionModel], Never> { get }
    var selectedOption: AnyPublisher<EventNotificationTimeOption?, Never> { get }
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple

final class EventNotificationDefaultTimeOptionViewModelImple: EventNotificationDefaultTimeOptionViewModel, @unchecked Sendable {
    
    let forAllDay: Bool
    private let notificationPermissionUsecase: any NotificationPermissionUsecase
    private let eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    var router: (any EventNotificationDefaultTimeOptionRouting)?
    
    init(
        forAllDay: Bool,
        notificationPermissionUsecase: any NotificationPermissionUsecase,
        eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    ) {
        self.forAllDay = forAllDay
        self.notificationPermissionUsecase = notificationPermissionUsecase
        self.eventNotificationSettingUsecase = eventNotificationSettingUsecase
    }
    
    
    private struct Subject {
        let notificationPermissionStatus = CurrentValueSubject<NotificationAuthorizationStatus?, Never>(nil)
        let optionModels = CurrentValueSubject<[DefaultTimeOptionModel]?, Never>(nil)
        let selecedOption = CurrentValueSubject<EventNotificationTimeOption??, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple Interactor

extension EventNotificationDefaultTimeOptionViewModelImple {
    
    func reload() {
    
        self.loadOptions()
        self.checkPermission()
    }
    
    private func loadOptions() {
        
        let savedOption = self.eventNotificationSettingUsecase.loadDefailtNotificationTimeOption(forAllDay: self.forAllDay)
        self.subject.selecedOption.send(savedOption)
        
        let options = self.eventNotificationSettingUsecase.availableTimes(forAllDay: self.forAllDay)
        let models: [DefaultTimeOptionModel] = [.init(option: nil)] + options.map { .init(option: $0) }
        self.subject.optionModels.send(models)
    }
    
    private func checkPermission() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let status = try await  self.notificationPermissionUsecase.checkAuthorizationStatus()
                self.subject.notificationPermissionStatus.send(status)
            } catch {
                self.subject.notificationPermissionStatus.send(.denied)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func requestPermission() {
        self.router?.openSystemNotificationSetting()
    }
    
    private func requestNotificationPermission() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let grant = try await self.notificationPermissionUsecase.requestPermission()
                if grant {
                    self.subject.notificationPermissionStatus.send(.authorized)
                } else {
                    self.showNotificationPermissionDenied()
                }
            } catch {
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func showNotificationPermissionDenied() {
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("event_notification_setting::need_permission_title".localized())
            |> \.message .~ pure("event_notification_setting::permission_denied".localized())
        self.router?.showConfirm(dialog: info)
    }
    
    func selectOption(_ option: EventNotificationTimeOption?) {
        self.subject.selecedOption.send(option)
        self.eventNotificationSettingUsecase.saveDefaultNotificationTimeOption(forAllDay: self.forAllDay, option: option)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple Presenter

extension EventNotificationDefaultTimeOptionViewModelImple {
    
    var isNeedNotificationPermission: AnyPublisher<Bool, Never> {
        let transform: (NotificationAuthorizationStatus) -> Bool = { status in
            return status == .denied
        }
        return self.subject.notificationPermissionStatus
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedOption: AnyPublisher<EventNotificationTimeOption?, Never> {
        return self.subject.selecedOption
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var options: AnyPublisher<[DefaultTimeOptionModel], Never> {
        return self.subject.optionModels
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
