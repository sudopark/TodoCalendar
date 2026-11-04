//
//  DDayTextTests.swift
//  Extensions
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing

@testable import Extensions


struct DDayTextTests {

    @Test("미래 이벤트는 D-n", arguments: [1, 3, 100])
    func ddayText_whenFuture_isDMinus(_ interval: Int) {
        // given
        // when
        let text = DDayText(interval).text
        // then
        #expect(text == "D-\(interval)")
    }

    @Test("당일은 D-Day")
    func ddayText_whenToday_isDDay() {
        // given
        // when
        let text = DDayText(0).text
        // then
        #expect(text == "D-Day")
    }

    @Test("지난 이벤트는 D+n", arguments: [-1, -3, -100])
    func ddayText_whenPast_isDPlus(_ interval: Int) {
        // given
        // when
        let text = DDayText(interval).text
        // then
        #expect(text == "D+\(abs(interval))")
    }
}


// MARK: - 디데이 일수 계산

extension DDayTextTests {

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func makeDates(_ calendar: Calendar, intervalDays: Int) -> (now: Date, target: Date) {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 15))!
        let targetDay = calendar.date(byAdding: .day, value: intervalDays, to: now)!
        let target = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDay)!
        return (now, target)
    }

    @Test("옵션을 끄면 diffDays 와 같다", arguments: [-3, 0, 4])
    func ddayInterval_whenOptionOff_equalsDiffDays(_ intervalDays: Int) {
        // given
        let calendar = self.makeCalendar()
        let (now, target) = self.makeDates(calendar, intervalDays: intervalDays)
        // when
        let interval = calendar.ddayInterval(now, target, countsTargetDayAsOne: false)
        // then
        #expect(interval == intervalDays)
    }

    @Test("옵션을 켜도 대상일 전은 그대로다", arguments: [1, 4])
    func ddayInterval_whenOptionOnAndFuture_keepsDiffDays(_ intervalDays: Int) {
        // given
        let calendar = self.makeCalendar()
        let (now, target) = self.makeDates(calendar, intervalDays: intervalDays)
        // when
        let interval = calendar.ddayInterval(now, target, countsTargetDayAsOne: true)
        // then
        #expect(interval == intervalDays)
    }

    @Test("옵션을 켜면 당일은 -1 이다")
    func ddayInterval_whenOptionOnAndTargetDay_isMinusOne() {
        // given
        let calendar = self.makeCalendar()
        let (now, target) = self.makeDates(calendar, intervalDays: 0)
        // when
        let interval = calendar.ddayInterval(now, target, countsTargetDayAsOne: true)
        // then
        #expect(interval == -1)
    }

    @Test("옵션을 켜면 지난 날은 하루를 더 뺀다", arguments: [(-1, -2), (-3, -4)])
    func ddayInterval_whenOptionOnAndPast_subtractsOneMore(_ intervalDays: Int, _ expected: Int) {
        // given
        let calendar = self.makeCalendar()
        let (now, target) = self.makeDates(calendar, intervalDays: intervalDays)
        // when
        let interval = calendar.ddayInterval(now, target, countsTargetDayAsOne: true)
        // then
        #expect(interval == expected)
    }
}
