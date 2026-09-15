//
//  TodayStyleSettingTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct TodayStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> TodayStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(TodayStyleSetting.self, from: data)
    }
}


extension TodayStyleSettingTests {

    @Test("초기값은 표시 항목을 전부 보여준다")
    func initial_showsEveryItem() {
        // given
        let setting = TodayStyleSetting.initial

        // when + then
        #expect(setting.showHolidayName == true)
        #expect(setting.showTimeZone == true)
        #expect(setting.showMonthYear == true)
        #expect(setting.showTotalCount == true)
        #expect(setting.showTodoCount == true)
        #expect(setting.showScheduleCount == true)
    }

    @Test("표시 항목을 인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = TodayStyleSetting.initial
            |> \.showHolidayName .~ false
            |> \.showTimeZone .~ true
            |> \.showTotalCount .~ false
            |> \.showTodoCount .~ true
            |> \.showScheduleCount .~ false

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(TodayStyleSetting.self, from: data)

        // then
        #expect(restored.showHolidayName == false)
        #expect(restored.showTimeZone == true)
        #expect(restored.showTotalCount == false)
        #expect(restored.showTodoCount == true)
        #expect(restored.showScheduleCount == false)
    }

    @Test("표시 항목이 늘기 전에 저장된 payload 는 없는 항목이 초기값으로 채워진다")
    func decodeLegacyPayload_fillsMissingItemsWithInitial() throws {
        // given
        let legacyText = """
        { "showHolidayName": false }
        """

        // when
        let setting = try self.decoded(legacyText)

        // then
        #expect(setting.showHolidayName == false)
        #expect(setting.showTimeZone == TodayStyleSetting.initial.showTimeZone)
        #expect(setting.showTotalCount == TodayStyleSetting.initial.showTotalCount)
        #expect(setting.showTodoCount == TodayStyleSetting.initial.showTodoCount)
        #expect(setting.showScheduleCount == TodayStyleSetting.initial.showScheduleCount)
    }

    @Test("항목이 하나도 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == TodayStyleSetting.initial)
    }
}
