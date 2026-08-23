//
//  AppColdLaunchHistoryTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct AppColdLaunchHistoryTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return self.calendar.date(from: components)!
    }
}


extension AppColdLaunchHistoryTests {

    @Test("최초 실행이면 firstLaunchDate 가 채워지고 count 는 1이 된다")
    func history_whenFirstLaunchEver_fillFirstLaunchDateAndCountOne() {
        // given
        var history = AppColdLaunchHistory()
        let now = self.date(2026, 8, 24)

        // when
        history.recordLaunch(at: now)

        // then
        #expect(history.firstLaunchDate == now)
        #expect(history.count == 1)
        #expect(history.lastLaunchDate == now)
        #expect(history.previousLaunchDate == nil)
    }

    @Test("실행마다 직전 실행일이 previousLaunchDate 로 이월된다")
    func history_onEachLaunch_carryLastLaunchDateIntoPreviousLaunchDate() {
        // given
        var history = AppColdLaunchHistory()
        let first = self.date(2026, 8, 20)
        let second = self.date(2026, 8, 21)
        let third = self.date(2026, 8, 22)

        // when
        history.recordLaunch(at: first)
        history.recordLaunch(at: second)
        history.recordLaunch(at: third)

        // then
        #expect(history.firstLaunchDate == first)
        #expect(history.previousLaunchDate == second)
        #expect(history.lastLaunchDate == third)
        #expect(history.count == 3)
    }

    @Test("직전 실행이 같은 날이면 그날 첫 실행이 아니다")
    func history_whenPreviousLaunchIsSameDay_isNotFirstLaunchOfDay() {
        // given
        var history = AppColdLaunchHistory()

        // when
        history.recordLaunch(at: self.date(2026, 8, 24, 9))
        history.recordLaunch(at: self.date(2026, 8, 24, 21))

        // then
        #expect(history.isFirstLaunchOfDay(self.calendar) == false)
    }

    @Test("직전 실행이 어제면 그날 첫 실행이다")
    func history_whenPreviousLaunchIsYesterday_isFirstLaunchOfDay() {
        // given
        var history = AppColdLaunchHistory()

        // when
        history.recordLaunch(at: self.date(2026, 8, 23, 21))
        history.recordLaunch(at: self.date(2026, 8, 24, 9))

        // then
        #expect(history.isFirstLaunchOfDay(self.calendar) == true)
    }

    @Test("직전 실행 기록이 없으면 그날 첫 실행이다")
    func history_whenNoPreviousLaunch_isFirstLaunchOfDay() {
        // given
        var history = AppColdLaunchHistory()

        // when
        history.recordLaunch(at: self.date(2026, 8, 24))

        // then
        #expect(history.isFirstLaunchOfDay(self.calendar) == true)
    }

    @Test("첫 실행일로부터의 경과일은 자정 기준으로 센다")
    func history_elapsedDaysFromFirstLaunch_countByStartOfDay() {
        // given
        var history = AppColdLaunchHistory()
        history.recordLaunch(at: self.date(2026, 8, 17, 23))

        // when
        let elapsedDays = history.elapsedDaysFromFirstLaunch(to: self.date(2026, 8, 24, 1), self.calendar)

        // then
        #expect(elapsedDays == 7)
    }

    @Test("첫 실행 기록이 없으면 경과일은 0이다")
    func history_whenNoFirstLaunchDate_elapsedDaysIsZero() {
        // given
        let history = AppColdLaunchHistory()

        // when
        let elapsedDays = history.elapsedDaysFromFirstLaunch(to: self.date(2026, 8, 24), self.calendar)

        // then
        #expect(elapsedDays == 0)
    }
}
