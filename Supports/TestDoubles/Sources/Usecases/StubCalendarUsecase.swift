//
//  StubCalendarUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/06/29.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


open class StubCalendarUsecase: CalendarUsecase {
    
    public init(
        today: CalendarComponent.Day = .init(year: 2023, month: 09, day: 10, weekDay: 1)
    ) {
        self.currentDaySubject.send(today)
    }
    
    private let currentDaySubject = CurrentValueSubject<CalendarComponent.Day?, Never>(nil)
    open var currentDay: AnyPublisher<CalendarComponent.Day, Never> {
        return self.currentDaySubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    open func components(
        for month: Int,
        of year: Int
    ) -> AnyPublisher<CalendarComponent, Never> {
     
        let components = try! self.getComponents(year, month, .sunday)
        return Just(components)
            .eraseToAnyPublisher()
    }
    
    open func getComponents(
        _ year: Int, _ month: Int, _ startDayOfWeek: DayOfWeeks
    ) throws -> CalendarComponent {
        let weekAndDays: [[(Int, Int)]] = [
            [(8, 27), (8, 28), (8, 29), (8, 30), (8, 31), (9, 1), (9, 2)],
            [(9, 3), (9, 4), (9, 5), (9, 6), (9, 7), (9, 8), (9, 9)],
            [(9, 10), (9, 11), (9, 12), (9, 13), (9, 14), (9, 15), (9, 16)],
            [(9, 17), (9, 18), (9, 19), (9, 20), (9, 21), (9, 22), (9, 23)],
            [(9, 24), (9, 25), (9, 26), (9, 27), (9, 28), (9, 29), (9, 30)]
        ]
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                return .init(year: year, month: pair.0, day: pair.1, weekDay: offset+1)
            }
            return CalendarComponent.Week(days: days)
        }
        return CalendarComponent(year: year, month: month, weeks: weeks)
    }
}
