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
import Domain
import Scenes


// MARK: - MainViewModel

protocol MainViewModel: AnyObject, Sendable, MainSceneInteractor {

    // interactor
    func prepare()
    func returnToToday()
    func startSearch()
    func moveToEventTypeFilterSetting()
    func moveToSetting()
    
    // presenter
    var currentMonth: AnyPublisher<String, Never> { get }
    var isShowReturnToToday: AnyPublisher<Bool, Never> { get }
}


// MARK: - MainViewModelImple

final class MainViewModelImple: MainViewModel, @unchecked Sendable {
    
    var router: (any MainRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        let focusedMonthInfo = CurrentValueSubject<(CalendarMonth, Bool)?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private var calendarSceneInteractor: (any CalendarSceneInteractor)?
}


// MARK: - MainViewModelImple Interactor

extension MainViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            self.calendarSceneInteractor = self.router?.attachCalendar()
        }
    }
    
    func returnToToday() {
        self.calendarSceneInteractor?.moveFocusToToday()
    }
    
    func startSearch() {
        // TODO:
    }
    
    func moveToEventTypeFilterSetting() {
        self.router?.routeToEventTypeFilterSetting()
    }
    
    func moveToSetting() {
        self.router?.routeToSettingScene()
    }
    
    func calendarScene(focusChangedTo month: CalendarMonth, isCurrentMonth: Bool) {
        self.subject.focusedMonthInfo.send((month, isCurrentMonth))
    }
}


// MARK: - MainViewModelImple Presenter

extension MainViewModelImple {
    
    var currentMonth: AnyPublisher<String, Never> {
        return self.subject.focusedMonthInfo
            .compactMap { $0 }
            .map { "\($0.0.month)" }
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
}
