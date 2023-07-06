//
//  WeekEventStackBuilderTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/07/07.
//

import XCTest
import Domain
import Prelude
import Optics
import UnitTestHelpKit

@testable import CalendarScenes


class WeekEventStackBuilderTests: BaseTestCase {
    
    
    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
    }
    private var dummyWeek: CalendarComponent.Week {
        let days = (1...7).map { int in
            return CalendarComponent.Day(year: 2023, month: 07, day: 8+int, weekDay: int)
        }
        return .init(days: days)
    }
    
    private func dummyEvent(on days: ClosedRange<Int>) -> CalendarEvent {
        let daysRange = days.lowerBound...days.upperBound
        let start = self.calendar.date(from: .init(year: 2023, month: 7, day: daysRange.lowerBound))!
            |> self.calendar.startOfDay(for:)
        let end = self.calendar.date(from: .init(year: 2023, month: 7, day: daysRange.upperBound))!
            |> { self.calendar.lastTimeOfDay(from: $0)! }
        
        let dates = start..<end
        let timeStamps = TimeStamp(dates.lowerBound.timeIntervalSince1970, timeZone: "KST")
            ..<
            TimeStamp(dates.upperBound.timeIntervalSince1970, timeZone: "KST")
        return .init(eventId: .schedule("\(daysRange)"), time: .period(timeStamps))
    }
    
    private func makeBuilder() -> WeekEventStackBuilder {
        return .init(TimeZone(abbreviation: "KST")!)
    }
}

extension WeekEventStackBuilderTests {
    
    func testBuilder_stackEvents_onlyOnThisWeek() {
        // given
        let builder = self.makeBuilder()
        let eventBeforeThisWeek = self.dummyEvent(on: 5...8)    // x
        let eventLeftJoinThisWeek = self.dummyEvent(on: 5...10)  // 7.9~10 겹침
        let eventRightJoinThisWeek = self.dummyEvent(on: 13...18)  //  7.13~15 겹침
        let eventInThisWeek = self.dummyEvent(on: 10...12)        // 7.10 ~ 7.12
        let eventAfterThisWeek = self.dummyEvent(on: 16...18)    // x
        let eventContainThisWeek = self.dummyEvent(on: 8...18)  // 7.9~15 겹침
        
        // when
        let stack = builder.build(self.dummyWeek, events: [
            eventBeforeThisWeek,
            eventLeftJoinThisWeek, eventRightJoinThisWeek, eventInThisWeek,
            eventAfterThisWeek,
            eventContainThisWeek
        ])
        
        // then
        let eventIds = stack.eventStacks.flatMap { $0 }.map { $0.eventId.idString } |> Set.init
        XCTAssertEqual(eventIds, [
            eventLeftJoinThisWeek.eventId.idString,
            eventRightJoinThisWeek.eventId.idString,
            eventInThisWeek.eventId.idString,
            eventContainThisWeek.eventId.idString
        ])
    }
    
    // 한주를 전체 채울수있도록 이벤드들을 조합해서 스택을 쌓음
    func testBuilder_combineAndStackEvents_toFillOneWeek() {
        // given
        let builder = self.makeBuilder()
        let eventSun_Sat = self.dummyEvent(on: 9...15)
        let eventSun_Mon = self.dummyEvent(on: 9...10)
        let eventTue_Sat = self.dummyEvent(on: 11...15)
        let eventSun_Tue = self.dummyEvent(on: 9...11)
        let eventWed_Thu = self.dummyEvent(on: 12...13)
        let eventFri_Sat = self.dummyEvent(on: 14...15)
        let eventSun = self.dummyEvent(on: 9...9)
        let eventMon = self.dummyEvent(on: 10...10)
        let eventTue = self.dummyEvent(on: 11...11)
        let eventWed = self.dummyEvent(on: 12...12)
        let eventThur = self.dummyEvent(on: 13...13)
        let eventFir = self.dummyEvent(on: 14...14)
        let eventSat = self.dummyEvent(on: 15...15)
        
        // when
        let stack = builder.build(self.dummyWeek, events: [
            eventSat, eventFir, eventThur, eventWed, eventTue, eventMon, eventSun,
            eventFri_Sat, eventWed_Thu, eventSun_Tue,
            eventTue_Sat, eventSun_Mon,
            eventSun_Sat
        ])
        
        // then
        let eventIdStacks = stack.eventStacks.map { row in row.map { $0.eventId } }
        XCTAssertEqual(eventIdStacks, [
            [ eventSun_Sat.eventId ],
            [ eventSun_Mon.eventId, eventTue_Sat.eventId ],
            [ eventSun_Tue.eventId, eventWed_Thu.eventId, eventFri_Sat.eventId ],
            [ eventSun.eventId, eventMon.eventId, eventTue.eventId, eventWed.eventId, eventThur.eventId, eventFir.eventId, eventSat.eventId ]
        ])
    }
    
    // 제일 길이가 긴 일정들을 조합해서 줄을 채우고 7일을 최대한 채운 기준으로 정렬
    func testBuilder_combineStacks_longestPeriodFirst_andSortByLength() {
        // given
        let builer = self.makeBuilder()
        let eventSun_Sat = self.dummyEvent(on: 9-8...15+3)
        let eventSun_Tue = self.dummyEvent(on: 9...11)
        let eventWed = self.dummyEvent(on: 12...12)
        let eventThu_Sat1 = self.dummyEvent(on: 13...15+4)
        let eventSun_Thu = self.dummyEvent(on: 9-6...13)
        let eventSat = self.dummyEvent(on: 15...15)
        let eventMon_Tue = self.dummyEvent(on: 10...11)
        let eventThu_Sat2 = self.dummyEvent(on: 13...15+9)
        let eventSun_Mon = self.dummyEvent(on: 9-7...10)
        let eventWed_Thu = self.dummyEvent(on: 12...13)
        
        // when
        let stack = builer.build(self.dummyWeek, events: [
            eventSun_Sat,
            eventSun_Tue, eventWed, eventThu_Sat1,
            eventSun_Thu, eventSat,
            eventMon_Tue, eventThu_Sat2,
            eventSun_Mon, eventWed_Thu
        ])
        
        // then
        let rangeLists = stack.eventStacks.map { row in row.map { $0.weekDaysRange } }
        XCTAssertEqual(rangeLists, [
            [ (1...7) ],
            [ (1...3), (4...4), (5...7) ],
            [ (1...5), (7...7) ],
            [ (1...2), (5...7) ],
            [ (2...3), (4...5) ]
        ])
    }
}


private extension EventId {
    
    var idString: String {
        switch self {
        case .todo(let id): return "t:\(id)"
        case .schedule(let id): return "s:\(id)"
        case .holiday(let id): return "h:\(id)"
        }
    }
}
