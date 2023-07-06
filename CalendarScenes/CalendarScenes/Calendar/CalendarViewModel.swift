//
//  CalendarViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/05.
//

import Foundation
import Combine
import Domain


struct Day: Equatable {
struct DayCellViewModel: Equatable {
    
    // TOOD: add event
    let year: Int
    let month: Int
    let day: Int
    let isNotCurrentMonth: Bool
    
    var identifier: String {
        "\(year)-\(month)-\(day)"
    }
}

struct WeekRowModel: Equatable {
    let days: [DayCellViewModel]
    
    init(_ week: CalendarComponent.Week, month: Int) {
        self.days = week.days.map { day -> DayCellViewModel in
            return .init(
                year: day.year,
                month: day.month,
                day: day.day,
                isNotCurrentMonth: day.month != month
            )
        }
    }
}

final class CalendarViewModelImple: @unchecked Sendable {
    
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let todoUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    
    init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        todoUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoUsecase = todoUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
    }
    
    private struct Subject: @unchecked Sendable {
        let currentTimeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let currentMonthComponent = CurrentValueSubject<CalendarComponent?, Never>(nil)
        let holidays = CurrentValueSubject<[Int: [Holiday]]?, Never>(nil)
        let userSelectedDay = CurrentValueSubject<Day?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
    private var currentMonthComponentsBinding: AnyCancellable?
}


extension CalendarViewModelImple: CalendarInteractor {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        
        let current = self.subject.currentMonthComponent.value
        let shouldChange = current?.year != newMonth.year || current?.month != newMonth.month
        guard shouldChange else { return }
        
        self.currentMonthComponentsBinding?.cancel()
        self.currentMonthComponentsBinding = self.calendarUsecase
            .components(for: newMonth.month, of: newMonth.year)
            .sink(receiveValue: { [weak self] component in
                self?.subject.currentMonthComponent.send(component)
            })
    }
    
    func holidayChanged(_ holidays: [Int : [Holiday]]) {
        
    }
    
    func select(_ day: DayCellViewModel) {
        self.subject.userSelectedDay.send(day)
    }
}

extension CalendarViewModelImple {
    
    var weekModels: AnyPublisher<[WeekRowModel], Never> {
        let transform: (CalendarComponent) -> [WeekRowModel]
        transform = { component in
            return component.weeks.map { week -> WeekRowModel in
                return .init(week, month: component.month)
            }
        }
        return self.subject.currentMonthComponent
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var currentSelectDayIdentifier: AnyPublisher<String, Never> {
        let transform: (DayCellViewModel?, CalendarComponent.Day, CalendarComponent) -> String
        transform = { selected, today, thisMonth in
            switch (selected, today, thisMonth) {
            case (.some(let day), _, let m) where day.month == m.month && day.year == m.year:
                return day.identifier
            case (_, let t, let m) where t.month != m.month:
                return "\(m.year)-\(m.month)-1"
            case (_, let t, _):
                return "\(t.year)-\(t.month)-\(t.day)"
            }
        }
        return Publishers.CombineLatest3(
            self.subject.userSelectedDay,
            self.calendarUsecase.currentDay,
            self.subject.currentMonthComponent.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
