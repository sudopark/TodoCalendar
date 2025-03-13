//
//  SelectDayDialogViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 3/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Scenes


protocol SelectDayDialogViewModel: Sendable, AnyObject {
    
    func select(_ date: Date)
    func confirmSelect()
    
    var initialCurrentSelectDate: Date { get }
}

final class SelectDayDialogViewModelImple: SelectDayDialogViewModel, @unchecked Sendable {
    
    private let currentDay: CalendarDay
    private let calendarUsecase: any CalendarUsecase
    var router: (any SelectDayDialogRouting)?
    weak var listener: (any SelectDayDialogSceneListener)?
    
    init(
        currentDay: CalendarDay,
        calendarUsecase: any CalendarUsecase
    ) {
        self.currentDay = currentDay
        self.calendarUsecase = calendarUsecase
        
        self.internalBinding()
    }
    
    private struct Subject {
        let selectedDay = CurrentValueSubject<CalendarComponent.Day?, Never>(nil)
        let today = CurrentValueSubject<CalendarComponent.Day?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    
    private func internalBinding() {
        
        self.calendarUsecase.currentDay.first()
            .sink(receiveValue: { [weak self] today in
                self?.subject.today.send(today)
            })
            .store(in: &self.cancellables)
    }
}


extension SelectDayDialogViewModelImple {
    
    func select(_ date: Date) {
        let day = CalendarComponent.Day(date, calendar: .current)
        self.subject.selectedDay.send(day)
    }
    
    func confirmSelect() {
        guard let selected = self.subject.selectedDay.value,
              let today = self.subject.today.value
        else { return }
        
        let selectInfo = SelectDayInfo(
            selected.year, selected.month, selected.day,
            isCurrentYear: selected.year == today.year,
            isCurrentDay: selected.year == today.year
                && selected.month == today.month
                && selected.day == today.day
        )
        self.router?.closeScene(animate: true) { [weak self] in
            self?.listener?.daySelectDialog(didSelect: selectInfo)
        }
    }
}


extension SelectDayDialogViewModelImple {
    
    var initialCurrentSelectDate: Date {
        let calendar = Calendar.current
        let components = DateComponents(
            year: self.currentDay.year,
            month: self.currentDay.month,
            day: self.currentDay.day
        )
        return calendar.date(from: components) ?? Date()
    }
}
