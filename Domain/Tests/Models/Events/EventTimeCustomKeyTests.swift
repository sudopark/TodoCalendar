//
//  EventTimeCustomKeyTests.swift
//  DomainTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct EventTimeCustomKeyTests {

    @Test("모든 EventTime 형태의 customKey에서 시작 시각을 읽는다")
    func lowerBoundFromCustomKey_forEveryCase() {
        // given
        let at = EventTime.at(1234)
        let period = EventTime.period(1234..<5678)
        let allDay = EventTime.allDay(1234..<5678, secondsFromGMT: 32400)

        // when + then
        #expect(EventTime.lowerBound(fromCustomKey: at.customKey) == 1234)
        #expect(EventTime.lowerBound(fromCustomKey: period.customKey) == 1234)
        #expect(EventTime.lowerBound(fromCustomKey: allDay.customKey) == 1234)
    }

    @Test("1970년 이전 시각도 읽는다")
    func lowerBoundFromCustomKey_whenNegative() {
        // given
        let time = EventTime.period(-5678 ..< -1234)

        // when
        let lowerBound = EventTime.lowerBound(fromCustomKey: time.customKey)

        // then
        #expect(lowerBound == -5678)
    }

    @Test("customKey 형식이 아니면 읽지 않는다", arguments: ["", "abc", "..<1234"])
    func lowerBoundFromCustomKey_whenMalformed_returnsNil(_ key: String) {
        // given + when
        let lowerBound = EventTime.lowerBound(fromCustomKey: key)

        // then
        #expect(lowerBound == nil)
    }
}
