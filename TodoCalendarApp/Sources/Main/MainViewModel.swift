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

public struct CurrentMonth: Equatable {
    let monthText: String
    var yearText: String?
}

protocol MainViewModel: AnyObject, Sendable, MainSceneInteractor {

    // interactor
    func prepare()
    func returnToToday()
    func handleMigration()
    func moveToEventTypeFilterSetting()
    func moveToSetting()
    func jumpDate()
    
    // presenter
    var currentMonth: AnyPublisher<CurrentMonth, Never> { get }
    var isShowReturnToToday: AnyPublisher<Bool, Never> { get }
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> { get }
    var isLoadingCalendarEvents: AnyPublisher<Bool, Never> { get }
}


// MARK: - MainViewModelImple

final class MainViewModelImple: MainViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    private let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    private let eventNotificationUsecase: any EventNotificationUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventNotifyService: SharedEventNotifyService
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    var router: (any MainRouting)?
    
    init(
        uiSettingUsecase: any UISettingUsecase,
        temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase,
        eventNotificationUsecase: any EventNotificationUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventNotifyService: SharedEventNotifyService,
        googleCalendarUsecase: any GoogleCalendarUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.temporaryUserDataMigrationUsecase = temporaryUserDataMigrationUsecase
        self.eventNotificationUsecase = eventNotificationUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventNotifyService = eventNotifyService
        self.googleCalendarUsecase = googleCalendarUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        let focusedDayInfo = CurrentValueSubject<SelectDayInfo?, Never>(nil)
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
        // TODO: google calendar 연동 여부에 따라 color 조회
        self.temporaryUserDataMigrationUsecase.checkIsNeedMigration()
        
        self.eventNotificationUsecase.runSyncEventNotification()
        self.bindEventTagColorMap()
        self.googleCalendarUsecase.prepare()
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
    
    func calendarScene(focusChangedTo selected: SelectDayInfo) {
        self.subject.focusedDayInfo.send(selected)
    }
    
    func jumpDate() {
        guard let current = self.subject.focusedDayInfo.value else { return }
        self.router?.showJumpDaySelectDialog(current: current.dayInfo)
    }
    
    func daySelectDialog(didSelect day: SelectDayInfo) {
        guard let current = self.subject.focusedDayInfo.value,
              current.dayInfo != day.dayInfo
        else { return }
        self.calendarSceneInteractor?.moveDay(day.dayInfo)
    }
}


// MARK: - MainViewModelImple Presenter

extension MainViewModelImple {
    
    var currentMonth: AnyPublisher<CurrentMonth, Never> {
        
        let formatter = DateFormatter() |> \.dateFormat .~ "date_form.MMM".localized()
        let calednar = Calendar(identifier: .gregorian)
        let transform: (SelectDayInfo?) -> CurrentMonth? = { info in
            guard let info else { return nil }
            guard let date = calednar.date(bySetting: .month, value: info.month, of: Date())
            else {
                return .init(monthText: "\(info.month)")
            }
            return .init(
                monthText: formatter.string(from: date).uppercased(),
                yearText: info.isCurrentYear ? nil : "\(info.year)"
            )
        }
        
        return self.subject.focusedDayInfo
            .compactMap(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowReturnToToday: AnyPublisher<Bool, Never> {
        return self.subject.focusedDayInfo
            .compactMap { $0 }
            .map { !$0.isCurrentDay }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> {
        return self.subject.temporaryUserDataMigrationStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isLoadingCalendarEvents: AnyPublisher<Bool, Never> {
        let transform: (RefreshingEvent) -> Bool = { event in
            switch event {
            case .refreshingTodo(let isLoading): return isLoading
            case .refreshingSchedule(let isLoading): return isLoading
            case .refreshForemostEvent(let isLoading): return isLoading
            case .refreshingCurrentTodo(let isLoading): return isLoading
            case .refreshingUncompletedTodo(let isLoading): return isLoading
            }
        }
        let refreshingEvent: AnyPublisher<RefreshingEvent, Never> = self.eventNotifyService.event()
        return refreshingEvent
            .compactMap(transform)
            .eraseToAnyPublisher()
    }
}
