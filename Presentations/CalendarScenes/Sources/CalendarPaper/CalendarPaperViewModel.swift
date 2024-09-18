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
    
    private var currentMonth: CalendarMonth
    
    var router: (any CalendarPaperRouting)?
    private var monthInteractor: any MonthSceneInteractor
    private var eventListInteractor: any DayEventListSceneInteractor
    weak var listener: (any CalendarPaperSceneListener)?
    
    init(
        month: CalendarMonth,
        monthInteractor: any MonthSceneInteractor,
        eventListInteractor: any DayEventListSceneInteractor
    ) {
        self.currentMonth = month
        self.monthInteractor = monthInteractor
        self.eventListInteractor = eventListInteractor
    }
    
    private var currentSelectedDayAndEvents: (CurrentSelectDayModel, [any CalendarEvent])?
}


// MARK: - CalendarPaperViewModelImple Interactor

extension CalendarPaperViewModelImple {
    
    func prepare() {
        if let pair = currentSelectedDayAndEvents {
            self.eventListInteractor.selectedDayChanaged(pair.0, and: pair.1)
        }
    }
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        self.currentMonth = newMonth
        self.monthInteractor.updateMonthIfNeed(newMonth)
    }
    
    func selectToday() {
        self.monthInteractor.clearDaySelection()
    }
    
    func monthScene(
        didChange currentSelectedDay: CurrentSelectDayModel,
        and eventsThatDay: [any CalendarEvent]
    ) {
        self.currentSelectedDayAndEvents = (currentSelectedDay, eventsThatDay)
        self.eventListInteractor.selectedDayChanaged(currentSelectedDay, and: eventsThatDay)
        self.listener?.calendarPaper(on: self.currentMonth, didChange: currentSelectedDay)
    }
}


// MARK: - CalendarPaperViewModelImple Presenter

extension CalendarPaperViewModelImple {
    
}
