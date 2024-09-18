//
//  
//  SelectEventNotificationTimeViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
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


struct NotificationTimeOptionModel: Equatable {
    let option: EventNotificationTimeOption?
    let text: String
    
    init(option: EventNotificationTimeOption?) {
        self.option = option
        self.text = option.text
    }
}

struct CustomTimeOptionModel: Equatable {
    let option: EventNotificationTimeOption
    let components: DateComponents
    let timeText: String
    
    init?(option: EventNotificationTimeOption) {
        guard case let .custom(compos) = option else { return nil }
        self.option = option
        self.components = compos
        let calendar = Calendar(identifier: .gregorian)
        self.timeText = calendar.customTimeText(compos) ?? ""
    }
}

// MARK: - SelectEventNotificationTimeViewModel

protocol SelectEventNotificationTimeViewModel: AnyObject, Sendable, SelectEventNotificationTimeSceneInteractor {

    // interactor
    func prepare()
    func toggleSelectDefaultOption(_ option: EventNotificationTimeOption?)
    func addCustomTimeOption(_ components: DateComponents)
    func removeCustomTimeOption(_ components: DateComponents)
    func moveSystemNotificationSetting()
    func close()
    
    // presenter
    var defaultTimeOptions: AnyPublisher<[NotificationTimeOptionModel], Never> { get }
    var customTimeOptions: AnyPublisher<[CustomTimeOptionModel], Never> { get }
    var selectedDefaultTimeOptions: AnyPublisher<[EventNotificationTimeOption], Never> { get }
    var suggestCustomTimeComponents: DateComponents { get }
    var isNeedNotificaitonPermission: AnyPublisher<Void, Never> { get }
}


// MARK: - SelectEventNotificationTimeViewModelImple

final class SelectEventNotificationTimeViewModelImple: SelectEventNotificationTimeViewModel, @unchecked Sendable {
    
    private let isForAllDay: Bool
    private let eventTimeComponents: DateComponents
    private let eventNotificationSettingUsecase: any EventNotificationSettingUsecase
    private let notificationPermissionUsecase: any NotificationPermissionUsecase
    var router: (any SelectEventNotificationTimeRouting)?
    var listener: (any SelectEventNotificationTimeSceneListener)?
    
    init(
        isForAllDay: Bool,
        startWith select: [EventNotificationTimeOption],
        eventTimeComponents: DateComponents,
        eventNotificationSettingUsecase: any EventNotificationSettingUsecase,
        notificationPermissionUsecase: any NotificationPermissionUsecase
    ) {
        self.isForAllDay = isForAllDay
        self.eventTimeComponents = eventTimeComponents
        self.eventNotificationSettingUsecase = eventNotificationSettingUsecase
        self.notificationPermissionUsecase = notificationPermissionUsecase
        self.subject.selectedOptions.send(select)
        
        self.bindChangedOptionChanged()
    }
    
    
    private struct Subject {
        let defaultOptions = CurrentValueSubject<[EventNotificationTimeOption]?, Never>(nil)
        let customOptions = CurrentValueSubject<[EventNotificationTimeOption]?, Never>(nil)
        let selectedOptions = CurrentValueSubject<[EventNotificationTimeOption]?, Never>(nil)
        let notificationPermissionDenied = PassthroughSubject<Void, Never>()
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func bindChangedOptionChanged() {
        
        self.subject.selectedOptions
            .compactMap { $0 }
            .dropFirst()
            .sink(receiveValue: { [weak self] options in
                self?.listener?.selectEventNotificationTime(didUpdate: options)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - SelectEventNotificationTimeViewModelImple Interactor

extension SelectEventNotificationTimeViewModelImple {
    
    func prepare() {
        
        let defaultOptions = self.eventNotificationSettingUsecase
            .availableTimes(forAllDay: self.isForAllDay)
        self.subject.defaultOptions.send(defaultOptions)
        
        self.requestNotificationPermissionIfNeed()
    }
    
    private func requestNotificationPermissionIfNeed() {
        
        Task { [weak self] in
            let status = try await self?.notificationPermissionUsecase.checkAuthorizationStatus()
            switch status {
            case .notDetermined:
                let isGrant = try await self?.notificationPermissionUsecase.requestPermission()
                if isGrant == false {
                    self?.subject.notificationPermissionDenied.send(())
                }
                
            case .denied:
                self?.subject.notificationPermissionDenied.send(())
            default: break
            }
        }
        .store(in: &self.cancellables)
    }
    
    func toggleSelectDefaultOption(_ option: EventNotificationTimeOption?) {
        guard let options = self.subject.selectedOptions.value
        else { return }
        
        let newOptionAndIndex = option.map {
            ($0, options.firstIndex(of: $0))
        }
        
        switch newOptionAndIndex {
        case .none:
            self.subject.selectedOptions.send(
                options.onlyCustomOptions()
            )
        case .some((let option, .none)):
            self.subject.selectedOptions.send(
                options + [option]
            )
            
        case (.some((_, .some(let ix)))):
            var newOptions = options; newOptions.remove(at: ix)
            self.subject.selectedOptions.send(newOptions)
        }
    }
    
    func addCustomTimeOption(_ components: DateComponents) {
        guard let options = self.subject.selectedOptions.value
        else { return }
        
        let newOptions = options.filter { $0.customOptionDateComponents != components }
        let newOption = EventNotificationTimeOption.custom(components)
        self.subject.selectedOptions.send(newOptions + [newOption])
    }
    
    func removeCustomTimeOption(_ components: DateComponents) {
        guard let options = self.subject.selectedOptions.value
        else { return }
        
        let newOptions = options.filter { $0.customOptionDateComponents != components }
        self.subject.selectedOptions.send(newOptions)
    }
    
    func moveSystemNotificationSetting() {
        self.router?.openSystemNotificationSetting()
    }
    
    func close() {
        self.router?.closeScene(animate: true, nil)
    }
}


// MARK: - SelectEventNotificationTimeViewModelImple Presenter

extension SelectEventNotificationTimeViewModelImple {
    
    var defaultTimeOptions: AnyPublisher<[NotificationTimeOptionModel], Never> {
        let transform: ([EventNotificationTimeOption]) -> [NotificationTimeOptionModel] = { options in
            return options.map { .init(option: $0) }
        }
        return self.subject.defaultOptions
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedDefaultTimeOptions: AnyPublisher<[EventNotificationTimeOption], Never> {
        let filterDefaultOptions: ([EventNotificationTimeOption]) -> [EventNotificationTimeOption] = { options in
            return options.filter { option in
                if case .custom = option {
                    return false
                } else{
                    return true
                }
            }
        }
        return self.subject.selectedOptions
            .compactMap { $0 }
            .map(filterDefaultOptions)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var customTimeOptions: AnyPublisher<[CustomTimeOptionModel], Never> {
        return self.subject.selectedOptions
            .compactMap { $0 }
            .map { $0.onlyCustomOptions() }
            .map { os in os.compactMap { .init(option: $0) } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var suggestCustomTimeComponents: DateComponents {
        return self.eventTimeComponents
    }
    
    var isNeedNotificaitonPermission: AnyPublisher<Void, Never> {
        return self.subject.notificationPermissionDenied
            .eraseToAnyPublisher()
    }
}

private extension Array where Element == EventNotificationTimeOption {
    
    func onlyCustomOptions() -> Array {
        return self.filter { option in
            guard case .custom = option else { return false }
            return true
        }
    }
}

extension EventNotificationTimeOption {
    
    var customOptionDateComponents: DateComponents? {
        guard case let .custom(compos) = self else { return nil }
        return compos
    }
}
