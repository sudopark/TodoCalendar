//
//  EventRepeatTimeEnumeratorNextAfterTests.swift
//  Domain
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct EventRepeatTimeEnumeratorNextAfterTests {

    private var origin: RepeatingTimes {
        // 1970-01-01 00:00 ~ 01:00 (UTC)
        return .init(time: .period(0..<3600), turn: 1)
    }

    private func makeEnumerator(
        endOption: EventRepeating.RepeatEndOption? = nil
    ) -> EventRepeatTimeEnumerator {
        let option = EventRepeatingOptions.EveryDay()
        return EventRepeatTimeEnumerator(option, endOption: endOption)!
    }
}

// MARK: - 기준 시각 이후 첫 회차 탐색

extension EventRepeatTimeEnumeratorNextAfterTests {

    @Test("기준 시각이 origin 종료 이전이면 origin을 그대로 반환")
    func nextAfter_whenRefTimeBeforeOriginEnd_returnsOrigin() {
        // given
        let enumerator = self.makeEnumerator()
        // when
        let next = enumerator.nextEventTime(after: 100, from: self.origin, until: nil)
        // then
        #expect(next?.turn == 1)
        #expect(next?.time == .period(0..<3600))
    }

    @Test("기준 시각이 3일 뒤면 4번째 회차 반환")
    func nextAfter_whenRefTimeIsThreeDaysLater_returnsFourthTurn() {
        // given
        let enumerator = self.makeEnumerator()
        let threeDays: TimeInterval = 3600 * 24 * 3
        // when
        let next = enumerator.nextEventTime(after: threeDays, from: self.origin, until: nil)
        // then
        #expect(next?.turn == 4)
        #expect(next?.time == .period(threeDays..<threeDays + 3600))
    }

    @Test("종료 시각을 넘어서면 nil")
    func nextAfter_whenRefTimeAfterRepeatEnd_returnsNil() {
        // given
        let twoDays: TimeInterval = 3600 * 24 * 2
        let enumerator = self.makeEnumerator(endOption: .until(twoDays))
        let tenDays: TimeInterval = 3600 * 24 * 10
        // when
        let next = enumerator.nextEventTime(after: tenDays, from: self.origin, until: twoDays)
        // then
        #expect(next == nil)
    }
}
