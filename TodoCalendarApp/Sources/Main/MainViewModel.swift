//
//  
//  MainViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - MainViewModel

enum TemporaryUserDataMigrationStatus: Equatable {
    case need(_ count: Int)
    case migrating
}

protocol MainViewModel: AnyObject, Sendable, MainSceneInteractor {

    // interactor
    func prepare()
    func returnToToday()
    func handleMigration()
    func moveToEventTypeFilterSetting()
    func moveToSetting()
    
    // presenter
    var currentMonth: AnyPublisher<String, Never> { get }
    var isShowReturnToToday: AnyPublisher<Bool, Never> { get }
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> { get }
}


// MARK: - MainViewModelImple

final class MainViewModelImple: MainViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    private let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    private let eventNotificationUsecase: any EventNotificationUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any MainRouting)?
    
    init(
        uiSettingUsecase: any UISettingUsecase,
        temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase,
        eventNotificationUsecase: any EventNotificationUsecase,
        eventTagUsecase: any EventTagUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.temporaryUserDataMigrationUsecase = temporaryUserDataMigrationUsecase
        self.eventNotificationUsecase = eventNotificationUsecase
        self.eventTagUsecase = eventTagUsecase
        
        self.internalBinding()
    }
    
    private typealias FocusMonthAndIsCurrentDay = (CalendarMonth, Bool)
    private struct Subject {
        let focusedMonthInfo = CurrentValueSubject<FocusMonthAndIsCurrentDay?, Never>(nil)
        let temporaryUserDataMigrationStatus = CurrentValueSubject<TemporaryUserDataMigrationStatus?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private var calendarSceneInteractor: (any CalendarSceneInteractor)?
    
    private func internalBinding() {
        
        self.temporaryUserDataMigrationUsecase.isMigrating
            .filter { $0 }
            .sink(receiveValue: { [weak self] _ in
                self?.subject.temporaryUserDataMigrationStatus.send(.migrating)
            })
            .store(in: &self.cancellables)
        
        self.temporaryUserDataMigrationUsecase.migrationNeedEventCount
            .filter { $0 > 0 }
            .sink(receiveValue: { [weak self] count in
                self?.subject.temporaryUserDataMigrationStatus.send(.need(count))
            })
            .store(in: &self.cancellables)
        
        self.temporaryUserDataMigrationUsecase.migrationResult
            .sink(receiveValue: { [weak self] result in
                self?.subject.temporaryUserDataMigrationStatus.send(nil)
                switch result {
                case .success:
                    self?.router?.showToast("manage_account::migration_finished::message".localized())
                case .failure(let error):
                    self?.router?.showError(error)
                }
            })
            .store(in: &self.cancellables)
    }
    
}


// MARK: - MainViewModelImple Interactor

extension MainViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            self.calendarSceneInteractor = self.router?.attachCalendar()
        }
        self.refreshViewAppearanceSettings()
        self.temporaryUserDataMigrationUsecase.checkIsNeedMigration()
        
        self.eventNotificationUsecase.runSyncEventNotification()
        self.bindEventTagColorMap()
    }
    
    private func refreshViewAppearanceSettings() {
        Task { [weak self] in
            _ = try await self?.uiSettingUsecase.refreshAppearanceSetting()
        }
        .store(in: &self.cancellables)
    }
    
    private func bindEventTagColorMap() {
        
        self.eventTagUsecase.sharedEventTags
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tags in
                self?.uiSettingUsecase.applyEventTagColors(Array(tags.values))
            })
            .store(in: &self.cancellables)
    }
    
    func returnToToday() {
        self.calendarSceneInteractor?.moveFocusToToday()
    }
    
    func handleMigration() {
        guard let status = self.subject.temporaryUserDataMigrationStatus.value,
              case .need(let count) = status
        else { return }
        
        let runMigration: () -> Void = { [weak self] in
            self?.temporaryUserDataMigrationUsecase.startMigration()
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("manage_account::migration::title".localized())
            |> \.message .~ pure("manage_account::migration::description".localized(with: count))
            |> \.withCancel .~ true
            |> \.confirmed .~ pure(runMigration)
        self.router?.showConfirm(dialog: info)
    }
    
    func moveToEventTypeFilterSetting() {
        self.router?.routeToEventTypeFilterSetting()
    }
    
    func moveToSetting() {
        self.router?.routeToSettingScene()
    }
    
    func calendarScene(focusChangedTo month: CalendarMonth, isCurrentDay: Bool) {
        self.subject.focusedMonthInfo.send((month, isCurrentDay))
    }
}


// MARK: - MainViewModelImple Presenter

extension MainViewModelImple {
    
    var currentMonth: AnyPublisher<String, Never> {
        
        let formatter = DateFormatter() |> \.dateFormat .~ "date_form.MMM".localized()
        let calednar = Calendar(identifier: .gregorian)
        let transform: (CalendarMonth) -> String = { month in
            guard let date = calednar.date(bySetting: .month, value: month.month, of: Date())
            else {
                return "\(month.month)"
            }
            return formatter.string(from: date).uppercased()
        }
        
        return self.subject.focusedMonthInfo
            .compactMap { $0?.0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowReturnToToday: AnyPublisher<Bool, Never> {
        return self.subject.focusedMonthInfo
            .compactMap { $0 }
            .map { !$0.1 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> {
        return self.subject.temporaryUserDataMigrationStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
