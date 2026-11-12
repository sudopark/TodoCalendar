//
//  LunarCalendarKindTests.swift
//  DomainTests
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Prelude
import Optics

@testable import Domain

private let seoul = TimeZone(identifier: "Asia/Seoul")!
private let hoChiMinh = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
private let isIOS26OrLater = ProcessInfo.processInfo.isOperatingSystemAtLeast(
    OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
)

struct LunarCalendarKindTests {

    private func date(_ year: Int, _ month: Int, _ day: Int, in timeZone: TimeZone) -> Date {
        let gregorian = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        return gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func lunarMonthDay(_ calendar: Calendar, _ date: Date) -> [Int] {
        let components = calendar.dateComponents([.month, .day], from: date)
        return [components.month ?? -1, components.day ?? -1]
    }
}


// MARK: - 언어 → 음력 기준

extension LunarCalendarKindTests {

    @Test func kind_fromKorean_isDangi() {
        #expect(LunarCalendarKind(language: .korean) == .dangi)
    }

    @Test func kind_fromJapanese_isDangi() {
        #expect(LunarCalendarKind(language: .japanese) == .dangi)
    }

    @Test func kind_fromVietnamese_isVietnamese() {
        #expect(LunarCalendarKind(language: .vietnamese) == .vietnamese)
    }

    @Test func kind_fromChineseEnglishOrNil_isChinese() {
        #expect(LunarCalendarKind(language: .chinese) == .chinese)
        #expect(LunarCalendarKind(language: .english) == .chinese)
        #expect(LunarCalendarKind(language: nil) == .chinese)
    }
}


// MARK: - OS 무관 계산

extension LunarCalendarKindTests {

    @Test func chineseCalendar_2027SeollalIsSecondDay() {
        // given
        let calendar = LunarCalendarKind.chinese.calendar(timeZone: seoul)

        // when
        let monthDay = self.lunarMonthDay(calendar, self.date(2027, 2, 7, in: seoul))

        // then
        #expect(monthDay == [1, 2])
    }

    @Test func calendar_appliesGivenTimeZone() {
        // given
        let timeZone = TimeZone(identifier: "America/New_York")!

        // when
        let dangi = LunarCalendarKind.dangi.calendar(timeZone: timeZone)
        let chinese = LunarCalendarKind.chinese.calendar(timeZone: timeZone)

        // then
        #expect(dangi.timeZone == timeZone)
        #expect(chinese.timeZone == timeZone)
    }
}


// MARK: - iOS 26 이상

extension LunarCalendarKindTests {

    @Test(.enabled(if: isIOS26OrLater))
    func dangiCalendar_2027SeollalIsLunarNewYear() {
        // given
        let calendar = LunarCalendarKind.dangi.calendar(timeZone: seoul)

        // when
        let monthDay = self.lunarMonthDay(calendar, self.date(2027, 2, 7, in: seoul))

        // then
        #expect(monthDay == [1, 1])
    }

    @Test(.enabled(if: isIOS26OrLater))
    func vietnameseCalendar_1968TetIsLunarNewYear() {
        // given
        let calendar = LunarCalendarKind.vietnamese.calendar(timeZone: hoChiMinh)

        // when
        let monthDay = self.lunarMonthDay(calendar, self.date(1968, 1, 29, in: hoChiMinh))

        // then
        #expect(monthDay == [1, 1])
    }
}


// MARK: - iOS 26 미만

extension LunarCalendarKindTests {

    @Test(.enabled(if: !isIOS26OrLater))
    func dangiAndVietnamese_beforeIOS26_useChineseCalendar() {
        // given
        let dangi = LunarCalendarKind.dangi.calendar(timeZone: seoul)
        let vietnamese = LunarCalendarKind.vietnamese.calendar(timeZone: hoChiMinh)

        // when
        let seollal = self.lunarMonthDay(dangi, self.date(2027, 2, 7, in: seoul))
        let tet = self.lunarMonthDay(vietnamese, self.date(1968, 1, 29, in: hoChiMinh))

        // then
        #expect(seollal == [1, 2])
        #expect(tet == [12, 30])
    }
}
