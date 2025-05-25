//
//  RRuleParserTests.swift
//  DomainTests
//
//  Created by sudo.park on 5/25/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Extensions
import UnitTestHelpKit

@testable import Domain

struct RRuleParserTests {
    
    @Test func parse_everyDay() {
        // given
        let text = "RRULE:FREQ=DAILY;INTERVAL=5"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .DAILY)
        #expect(rrule?.interval == 5)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyWeek() {
        // given
        let text = "RRULE:FREQ=WEEKLY;BYDAY=TU"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(weekDay: .TU)])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyMonthNthWeekDay() {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYDAY=-1WE"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .MONTHLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(ordinal: -1, weekDay: .WE)])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyMonthSomeDay() {
        // given
        let text = "RRULE:FREQ=MONTHLY;INTERVAL=2"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .MONTHLY)
        #expect(rrule?.interval == 2)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyYear() {
        // given
        let text = "RRULE:FREQ=YEARLY"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .YEARLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyWorkDay() {
        // given
        let text = "RRULE:FREQ=WEEKLY;BYDAY=FR,MO,TH,TU,WE"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [
            .init(weekDay: .FR), .init(weekDay: .MO), .init(weekDay: .TH),
            .init(weekDay: .TU), .init(weekDay: .WE)
        ])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_endTime() {
        // given
        let text = "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20250816T145959Z;BYDAY=SA"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(weekDay: .SA)])
        #expect(rrule?.until != nil)
        let endtimeText = rrule?.until.flatMap {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter.string(from: $0)
        }
        #expect(endtimeText == "2025-08-16T14:59:59Z")
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_endCount() {
        // given
        let text = "RRULE:FREQ=DAILY;COUNT=3"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .DAILY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == 3)
    }
}
