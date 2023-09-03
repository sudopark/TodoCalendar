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
    
    private var currentSelectedDayAndEvents: (CurrentSelectDayModel, [EventId])?
}


// MARK: - CalendarPaperViewModelImple Interactor

extension CalendarPaperViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            let interactors = self.router?.attachMonthAndEventList(self.month) ?? nil
            self.monthInteractor = interactors?.0
            self.eventListInteractor = interactors?.1
            if let pair = currentSelectedDayAndEvents {
                self.eventListInteractor?.selectedDayChanaged(pair.0, and: pair.1)
            }
        }
    }
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        self.monthInteractor?.updateMonthIfNeed(newMonth)
    }
    
    func monthScene(
        didChange currentSelectedDay: CurrentSelectDayModel,
        and eventsThatDay: [EventId]
    ) {
        self.currentSelectedDayAndEvents = (currentSelectedDay, eventsThatDay)
        self.eventListInteractor?.selectedDayChanaged(currentSelectedDay, and: eventsThatDay)
    }
}


// MARK: - CalendarPaperViewModelImple Presenter

extension CalendarPaperViewModelImple {
    
}
