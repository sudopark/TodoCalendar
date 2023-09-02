//
//  
//  CalendarPaperViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - CalendarPaperViewModel

protocol CalendarPaperViewModel: AnyObject, Sendable, CalendarPaperSceneInteractor {

    // interactor
    func prepare()
    
    // presenter
}


// MARK: - CalendarPaperViewModelImple

final class CalendarPaperViewModelImple: CalendarPaperViewModel, @unchecked Sendable {
    
    private let month: CalendarMonth
    
    var router: CalendarPaperRouting?
    private var monthInteractor: MonthSceneInteractor?
    private var eventListInteractor: DayEventListSceneInteractor?
    
    init(month: CalendarMonth) {
        self.month = month
    }
    
    private var currentSelectedDay: CurrentSelectDayModel?
}


// MARK: - CalendarPaperViewModelImple Interactor

extension CalendarPaperViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            let interactors = self.router?.attachMonthAndEventList(self.month) ?? nil
            self.monthInteractor = interactors?.0
            self.eventListInteractor = interactors?.1
            if let currentSelectedDay {
                self.eventListInteractor?.selectedDayChanaged(currentSelectedDay)
            }
        }
    }
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        self.monthInteractor?.updateMonthIfNeed(newMonth)
    }
    
    func monthScene(didChange currentSelectedDay: CurrentSelectDayModel) {
        // TODO: 초기 선택일 정보 전달될때 리스너 아직 준비 안되어있을수도있음
        self.currentSelectedDay = currentSelectedDay
        self.eventListInteractor?.selectedDayChanaged(currentSelectedDay)
    }
}


// MARK: - CalendarPaperViewModelImple Presenter

extension CalendarPaperViewModelImple {
    
}
