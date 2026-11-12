//
//  RokuyoTests.swift
//  CalendarDomainTests
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import CalendarDomainInterface


struct RokuyoTests {

    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarComponent.Day {
        return .init(year: year, month: month, day: day, weekDay: 1)
    }
}

private enum Constant {
    static let isDangiAvailable: Bool = {
        guard #available(iOS 26, *) else { return false }
        return true
    }()
}


// MARK: - 음력 월·일에서 로쿠요 매핑

extension RokuyoTests {

    @Test(
        "(lunar month + lunar day) mod 6 picks rokuyo",
        arguments: [
            (1, 1, Rokuyo.sensho),
            (1, 2, Rokuyo.tomobiki),
            (1, 5, Rokuyo.taian),
            (2, 1, Rokuyo.tomobiki),
            (6, 30, Rokuyo.taian),
            (12, 29, Rokuyo.butsumetsu)
        ]
    )
    func rokuyo_mapsLunarMonthAndDaySumModSix(_ month: Int, _ day: Int, _ expected: Rokuyo) {
        // given + when
        let rokuyo = Rokuyo(lunarMonth: month, lunarDay: day)

        // then
        #expect(rokuyo == expected)
    }

    @Test func rokuyo_allCasesAreSixInOrder() {
        // given + when
        let cases = Rokuyo.allCases

        // then
        #expect(cases == [.taian, .shakku, .sensho, .tomobiki, .senbu, .butsumetsu])
        #expect(cases.map { $0.rawValue } == [0, 1, 2, 3, 4, 5])
    }
}


// MARK: - dangi 캘린더를 못 만드는 기기

extension RokuyoTests {

    @Test(.enabled(if: !Constant.isDangiAvailable))
    func rokuyo_whenDangiUnavailable_isNil() {
        // given
        let days = [self.day(2026, 10, 6), self.day(2026, 10, 10), self.day(2025, 8, 1)]

        // when
        let rokuyos = days.map { Rokuyo($0) }

        // then
        #expect(rokuyos == [nil, nil, nil])
    }
}


// MARK: - dangi 캘린더로 일본 달력과 같은 값

extension RokuyoTests {

    @Test(.enabled(if: Constant.isDangiAvailable))
    func rokuyo_matchesJapaneseCalendar_october2026() {
        // given
        let senbuDays = [6, 11, 17, 23, 29].map { self.day(2026, 10, $0) }
        let senshoDay = self.day(2026, 10, 10)

        // when
        let senbuRokuyos = senbuDays.map { Rokuyo($0) }
        let senshoRokuyo = Rokuyo(senshoDay)

        // then
        #expect(senbuRokuyos == Array(repeating: .senbu, count: 5))
        #expect(senshoRokuyo == .sensho)
    }

    @Test(.enabled(if: Constant.isDangiAvailable))
    func rokuyo_leapMonth_usesSameMonthNumber() {
        // given
        let leapSixthMonthEighthDay = self.day(2025, 8, 1)

        // when
        let rokuyo = Rokuyo(leapSixthMonthEighthDay)

        // then
        #expect(rokuyo == .sensho)
    }
}
