//
//  MonthStyleSettingTests.swift
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


struct MonthStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> MonthStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(MonthStyleSetting.self, from: data)
    }
}


extension MonthStyleSettingTests {

    @Test("초기값은 표시 항목을 전부 보여준다")
    func initial_showsEveryItem() {
        // given
        let setting = MonthStyleSetting.initial

        // when + then
        #expect(setting.showMonthName == true)
        #expect(setting.showWeekDayHeader == true)
        #expect(setting.highlightToday == true)
        #expect(setting.showEventUnderline == true)
    }

    @Test("표시 항목을 인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = MonthStyleSetting.initial
            |> \.showMonthName .~ false
            |> \.showWeekDayHeader .~ true
            |> \.highlightToday .~ false
            |> \.showEventUnderline .~ true

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(MonthStyleSetting.self, from: data)

        // then
        #expect(restored.showMonthName == false)
        #expect(restored.showWeekDayHeader == true)
        #expect(restored.highlightToday == false)
        #expect(restored.showEventUnderline == true)
    }

    @Test("표시 항목이 늘기 전에 저장된 payload 는 없는 항목이 초기값으로 채워진다")
    func decodeLegacyPayload_fillsMissingItemsWithInitial() throws {
        // given
        let legacyText = """
        { "showMonthName": false }
        """

        // when
        let setting = try self.decoded(legacyText)

        // then
        #expect(setting.showMonthName == false)
        #expect(setting.showWeekDayHeader == MonthStyleSetting.initial.showWeekDayHeader)
        #expect(setting.highlightToday == MonthStyleSetting.initial.highlightToday)
        #expect(setting.showEventUnderline == MonthStyleSetting.initial.showEventUnderline)
    }

    @Test("항목이 하나도 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == MonthStyleSetting.initial)
    }
}
