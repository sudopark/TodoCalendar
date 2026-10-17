//
//  WeekEventsStyleSettingTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct WeekEventsStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> WeekEventsStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(WeekEventsStyleSetting.self, from: data)
    }
}


extension WeekEventsStyleSettingTests {

    @Test("초기값은 표시 항목을 전부 보여준다")
    func initial_showsEveryItem() {
        // given
        let setting = WeekEventsStyleSetting.initial

        // when + then
        #expect(setting.showWeekDayHeader == true)
    }

    @Test("표시 항목을 인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = WeekEventsStyleSetting.initial
            |> \.showWeekDayHeader .~ false

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(WeekEventsStyleSetting.self, from: data)

        // then
        #expect(restored.showWeekDayHeader == false)
    }

    @Test("항목이 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == WeekEventsStyleSetting.initial)
    }
}
