//
//  
//  CalendarPaperScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import Domain


// MARK: - CalendarPaperScene Interactable & Listenable

protocol CalendarPaperSceneInteractor: Sendable, AnyObject, MonthSceneListener {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
    func selectToday()
    func selectDay(_ day: CalendarDay)
}
//
protocol CalendarPaperSceneListener: AnyObject {
    
    func calendarPaper(
        on month: CalendarMonth, didChange selectedDay: CurrentSelectDayModel
    )
}

// MARK: - CalendarPaperScene

protocol CalendarPaperScene: Scene where Interactor == any CalendarPaperSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol CalendarPaperSceneBuiler: AnyObject {
    
    // TODO: month 삭제 예정
    @MainActor
    func makeCalendarPaperScene(
        _ month: CalendarMonth,
        listener: (any CalendarPaperSceneListener)?
    ) -> any CalendarPaperScene
}
