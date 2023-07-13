//
//  Dummies.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/02.
//

import Foundation
import Prelude
import Optics
import Domain

extension TimeStamp {
    
    public static func dummy(_ int: Int = 0) -> TimeStamp {
        return .init(TimeInterval(int), timeZone: "UTC")
    }
}

extension TodoEvent {
    
    public static func dummy(_ int: Int = 0) -> TodoEvent {
        return .init(uuid: "id:\(int)", name: "name:\(int)")
    }
}

extension DoneTodoEvent {
    
    public static func dummy(_ int: Int = 0) -> DoneTodoEvent {
        return .init(uuid: "did:\(int)", name: "name:\(int)", originEventId: "id:\(int)", doneTime: .now)
    }
}


extension CalendarComponent {
    
    public static func dummy2023_9() -> CalendarComponent {
        let weekAndDays: [[(Int, Int)]] = [
            [(8, 27), (8, 28), (8, 29), (8, 30), (8, 31), (9, 1), (9, 2)],
            [(9, 3), (9, 4), (9, 5), (9, 6), (9, 7), (9, 8), (9, 9)],
            [(9, 10), (9, 11), (9, 12), (9, 13), (9, 14), (9, 15), (9, 16)],
            [(9, 17), (9, 18), (9, 19), (9, 20), (9, 21), (9, 22), (9, 23)],
            [(9, 24), (9, 25), (9, 26), (9, 27), (9, 28), (9, 29), (9, 30)]
        ]
        let holidays: [Holiday] = [
            .init(dateString: "2023-09-28", localName: "추석", name: "추석"),
            .init(dateString: "2023-09-29", localName: "추석", name: "추석"),
            .init(dateString: "2023-09-30", localName: "추석", name: "추석")
        ]
        return dummy(2023, 9, weekAndDays)
            .applyHolidays(holidays)
    }
    
    public static func dummy2023_8() -> CalendarComponent {
        let weekAndDays: [[(Int, Int)]] = [
            [(7, 30), (7, 31), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5)],
            [(8, 6), (8, 7), (8, 8), (8, 9), (8, 10), (8, 11), (8, 12)],
            [(8, 13), (8, 14), (8, 15), (8, 16), (8, 17), (8, 18), (8, 19)],
            [(8, 20), (8, 21), (8, 22), (8, 23), (8, 24), (8, 25), (8, 26)],
            [(8, 27), (8, 28), (8, 29), (8, 30), (8, 31), (9, 1), (9, 2)],
        ]
        let holidays: [Holiday] = [
            .init(dateString: "2023-08-15", localName: "광복절", name: "광복절")
        ]
        return dummy(2023, 8, weekAndDays)
            .applyHolidays(holidays)
    }
    
    private static func dummy(_ year: Int, _ month: Int, _ weekAndDays: [[(Int, Int)]]) -> CalendarComponent {
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                return .init(year: year, month: pair.0, day: pair.1, weekDay: offset+1)
            }
            return CalendarComponent.Week(days: days)
        }
        let components = CalendarComponent(year: year, month: month, weeks: weeks)
        return components
    }
}

private extension CalendarComponent {
    
    func applyHolidays(_ holidays: [Holiday]) -> CalendarComponent {
        let holidaysMap = holidays.asDictionary { $0.dateString }
        let newWeeks = self.weeks.map { week -> CalendarComponent.Week in
            let newDays = week.days.map { day -> CalendarComponent.Day in
                let dateString = "\(day.year)-\(day.month.withLeadingZero())-\(day.day.withLeadingZero())"
                return day |> \.holiday .~ holidaysMap[dateString]
            }
            return .init(days: newDays)
        }
        return .init(year: self.year, month: self.month, weeks: newWeeks)
    }
}
