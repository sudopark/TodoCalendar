//
//  CountdownTextTests.swift
//  ExtensionsTests
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Extensions


struct CountdownTextTests {

    private let locale = Locale(identifier: "en_US")
    private let deadline = Date(timeIntervalSince1970: 1780358400)

    private func date(remaining: TimeInterval) -> Date {
        return self.deadline.addingTimeInterval(-remaining)
    }
}


// MARK: - 남은 시간 문구

extension CountdownTextTests {

    @Test(
        "남은 크기에 맞는 단위로 최대 2개까지 표기",
        arguments: [
            (97_200.0, "1 day, 3 hr"),
            (86_401.0, "1 day"),
            (14_430.0, "4 hr"),
            (11_525.0, "3 hr, 12 min"),
            (90.0, "1 min, 30 sec"),
            (52.0, "52 sec"),
            (0.5, "1 sec")
        ]
    )
    func countdown_text(_ remaining: TimeInterval, _ expected: String) {
        // given
        // when
        let text = remaining.countdownText(locale: self.locale)
        // then
        #expect(text == expected)
    }

    @Test("남은 시간이 없으면 문구 없음", arguments: [0.0, -1.0, -3_600.0])
    func countdown_whenNoRemaining_textIsNil(_ remaining: TimeInterval) {
        // given
        // when
        let text = remaining.countdownText(locale: self.locale)
        // then
        #expect(text == nil)
    }
}


// MARK: - 갱신 시각

extension CountdownTextTests {

    @Test(
        "표기 단위에 맞는 간격으로 다음 갱신 — 초 구간 1초, 분 구간 1분, 일 구간 1시간",
        arguments: [
            (97_200.0, 3_600.0),
            (7_200.0, 60.0),
            (3_600.0, 1.0),
            (90.0, 1.0),
            (0.5, 0.5)
        ]
    )
    func countdown_nextTick(_ remaining: TimeInterval, _ expectedAfter: TimeInterval) {
        // given
        let now = self.date(remaining: remaining)
        // when
        let next = now.nextCountdownTick(until: self.deadline)
        // then
        #expect(next == now.addingTimeInterval(expectedAfter))
    }

    @Test("갱신 시각은 deadline 에 정렬 — 마지막 갱신이 deadline")
    func countdown_lastTickIsDeadline() {
        // given
        let now = self.date(remaining: 3.5)
        // when
        let ticks = sequence(first: now) { $0.nextCountdownTick(until: self.deadline) }
        // then
        #expect(Array(ticks.dropFirst()) == [
            self.date(remaining: 3.0), self.date(remaining: 2.0),
            self.date(remaining: 1.0), self.deadline
        ])
    }

    @Test("deadline 이후엔 갱신 없음")
    func countdown_whenPassedDeadline_noNextTick() {
        // given
        let now = self.date(remaining: -1)
        // when
        let next = now.nextCountdownTick(until: self.deadline)
        // then
        #expect(next == nil)
    }
}
