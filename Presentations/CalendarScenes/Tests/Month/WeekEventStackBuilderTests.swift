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
    
    private func dummyEvent(on days: ClosedRange<Int>, startTimeOffset: TimeInterval = 0) -> any CalendarEvent {
        let daysRange = days.lowerBound...days.upperBound
        let start = self.calendar.date(from: .init(year: 2023, month: 7, day: daysRange.lowerBound))!
            |> self.calendar.startOfDay(for:)
            |> { $0.addingTimeInterval(startTimeOffset) }
        let end = self.calendar.date(from: .init(year: 2023, month: 7, day: daysRange.upperBound))!
            |> { self.calendar.endOfDay(for: $0)! }
        
        let dates = start..<end
        let timeStamps = dates.lowerBound.timeIntervalSince1970
            ..<
            dates.upperBound.timeIntervalSince1970
        let todo = TodoEvent(uuid: "\(daysRange)+\(startTimeOffset)", name: "some") |> \.time .~ .period(timeStamps)
        return TodoCalendarEvent(todo, in: TimeZone(abbreviation: "KST")!)
    }
    
    private func makeBuilder() -> WeekEventStackBuilder {
        return .init(TimeZone(abbreviation: "KST")!)
    }
}

// MARK: - test calendar event

extension WeekEventStackBuilderTests {
    
    func dummyRange(in timeZone: TimeZone) -> Range<TimeInterval> {
        return try! TimeInterval.range(
            from: "2023-07-23 00:00:00",
            to: "2023-07-23 23:59:59",
            in: timeZone
        )
    }
    
    // make event from time + allday
    func testCalerdarEvent_makeFromEventTime_allDay() {
        // given
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        let range = self.dummyRange(in: kstTimeZone)
        let offset = kstTimeZone.secondsFromGMT(
            for: Date(timeIntervalSince1970: range.lowerBound)
        )
        let time = EventTime.allDay(range, secondsFromGMT: offset |> TimeInterval.init)
        
        func parameterizeTest(_ timeZone: TimeZone) {
            // given
            // when
            let event = TodoCalendarEvent(
                .init(uuid: "dummy", name: "some") |> \.time .~ time,
                in: timeZone
            )
            
            // then
            let expectedRange = self.dummyRange(in: timeZone)
            XCTAssertEqual(event.eventTimeOnCalendar, .period(expectedRange))
        }
        
        // when
        let timeZones: [TimeZone] = [
            .init(abbreviation: "KST")!, .init(abbreviation: "UTC")!,
            .init(secondsFromGMT: 14*3600)!, .init(secondsFromGMT: -12*3600)!
        ]
        // pdt는 제외해야함
        // expect는 계산시에 해당시간(7월) 기준으로 계산함(pdt) -> 비교값이 잘못됨
        // 허나 이벤트 타임 계산시에는 pst로(햔재시간 기준) 계산함
        
        // then
        timeZones.forEach(parameterizeTest(_:))
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
        let eventIds = stack.eventStacks.flatMap { $0 }.map { $0.eventId } |> Set.init
        XCTAssertEqual(eventIds, [
            eventLeftJoinThisWeek.eventId,
            eventRightJoinThisWeek.eventId,
            eventInThisWeek.eventId,
            eventContainThisWeek.eventId
        ])
        
        // 9 ~ 15
        let eventIdsPerDay = stack.eventsPerDay.map { es in es.map { $0.eventId } }
        XCTAssertEqual(eventIdsPerDay, [
           [ eventContainThisWeek.eventId, eventLeftJoinThisWeek.eventId, ],    // 9
           [ eventContainThisWeek.eventId, eventInThisWeek.eventId, eventLeftJoinThisWeek.eventId ], // 10,
           [ eventContainThisWeek.eventId, eventInThisWeek.eventId],   // 11
           [ eventContainThisWeek.eventId, eventInThisWeek.eventId],  // 12
           [ eventContainThisWeek.eventId, eventRightJoinThisWeek.eventId],  // 13
           [ eventContainThisWeek.eventId, eventRightJoinThisWeek.eventId ],      // 14
           [ eventContainThisWeek.eventId, eventRightJoinThisWeek.eventId ]   // 15
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
        let rangeLists = stack.eventStacks.map { row in row.map { $0.daysSequence } }
        XCTAssertEqual(rangeLists, [
            [ (1...7) ],
            [ (1...3), (4...4), (5...7) ],
            [ (1...5), (7...7) ],
            [ (1...2), (5...7) ],
            [ (2...3), (4...5) ]
        ])
    }
    
    func testBuilder_whenEventIsSameDay_sortByEventTimeAsc() {
        // given
        let builder = self.makeBuilder()
        
        // when
        let stack = builder.build(self.dummyWeek, events: [
            self.dummyEvent(on: 12...12, startTimeOffset: 30),
            self.dummyEvent(on: 12...12, startTimeOffset: 10),
            self.dummyEvent(on: 12...12, startTimeOffset: 23)
        ])
        
        // then
        let ids = stack.eventStacks.map { row in row.map { $0.event.eventId } }
        XCTAssertEqual(ids, [
            ["12...12+10.0"],
            ["12...12+23.0"],
            ["12...12+30.0"]
        ])
    }
}
