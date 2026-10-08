//
//  CalendarTwoColumnsViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Scenes
import CalendarPresentation


// MARK: - CalendarTwoColumnsViewModel

protocol CalendarTwoColumnsViewModel: AnyObject, Sendable, CalendarTwoColumnsSceneInteractor {

    var requestScrollToVoiceInput: AnyPublisher<Void, Never> { get }
}


// MARK: - CalendarTwoColumnsViewModelImple

final class CalendarTwoColumnsViewModelImple: CalendarTwoColumnsViewModel, @unchecked Sendable {

    var router: (any CalendarTwoColumnsRouting)?
    weak var listener: (any CalendarTwoColumnsSceneListener)?
    private let continuousMonthsInteractor: any ContinuousMonthsSceneInteractor
    private let eventListInteractor: any DayEventListSceneInteractor
    private let nextDayInteractor: any NextDayEventListSceneInteractor

    init(
        continuousMonthsInteractor: any ContinuousMonthsSceneInteractor,
        eventListInteractor: any DayEventListSceneInteractor,
        nextDayInteractor: any NextDayEventListSceneInteractor
    ) {
        self.continuousMonthsInteractor = continuousMonthsInteractor
        self.eventListInteractor = eventListInteractor
        self.nextDayInteractor = nextDayInteractor
    }

    private struct Subject {
        let requestScrollToVoiceInput = PassthroughSubject<Void, Never>()
    }
    private let subject = Subject()
}


// MARK: - CalendarTwoColumnsViewModelImple Interactor

extension CalendarTwoColumnsViewModelImple {

    func changeFocusedMonth(to month: CalendarMonth) {
        self.continuousMonthsInteractor.changeFocusedMonth(to: month)
    }

    func selectDay(_ day: CalendarDay) {
        self.continuousMonthsInteractor.selectDay(day)
    }

    func selectedDayIsToday(_ isToday: Bool) {
        self.eventListInteractor.selectedDayIsToday(isToday)
    }

    func scrollToVoiceInput() {
        self.subject.requestScrollToVoiceInput.send(())
    }
}


// MARK: - ContinuousMonthsSceneListener

extension CalendarTwoColumnsViewModelImple {

    func continuousMonths(didScrollTo month: CalendarMonth) {
        self.listener?.calendarTwoColumns(didScrollTo: month)
    }

    func continuousMonths(didSelect day: CalendarDay) {
        self.listener?.calendarTwoColumns(didSelect: day)
    }

    func continuousMonths(didRequestShare range: Range<TimeInterval>, kind: CalendarShareRangeKind) {
        self.router?.showSharePreview(range: range, kind: kind)
    }

    func continuousMonths(didChangeSelectedDay day: SelectDayAndEvents, and nextDays: [SelectDayAndEvents]) {
        self.eventListInteractor.selectedDayChanaged(day.0, and: day.1)
        guard let nextDay = nextDays.first else { return }
        self.nextDayInteractor.nextDayChanged(nextDay.0, and: nextDay.1)
    }
}


// MARK: - DayEventListSceneListener

extension CalendarTwoColumnsViewModelImple {

    func dayEventListDidRequestShowAICommand() {
        self.listener?.calendarTwoColumnsDidRequestShowAICommand()
    }

    func dayEventListDidRequestReturnToToday() {
        self.listener?.calendarTwoColumnsDidRequestReturnToToday()
    }
}


// MARK: - CalendarTwoColumnsViewModelImple Presenter

extension CalendarTwoColumnsViewModelImple {

    var requestScrollToVoiceInput: AnyPublisher<Void, Never> {
        return self.subject.requestScrollToVoiceInput
            .eraseToAnyPublisher()
    }
}
