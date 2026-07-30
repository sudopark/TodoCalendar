//
//  DDayTextTests.swift
//  Extensions
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

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
