//
//  WeekEventsStyleSettingTests.swift
//  SettingDomainTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
@testable import SettingDomain
@testable import SettingDomainInterface



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

    @Test("표시 항목·글자 크기를 인코딩했다가 디코딩해도 고른 값이 그대로 남는다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = WeekEventsStyleSetting.initial
            |> \.showWeekDayHeader .~ false
            |> \.eventTextSize .~ 10

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(WeekEventsStyleSetting.self, from: data)

        // then
        #expect(restored.showWeekDayHeader == false)
        #expect(restored.eventTextSize == 10)
    }

    @Test("항목이 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == WeekEventsStyleSetting.initial)
    }
}


// MARK: - 일정 글자 크기

extension WeekEventsStyleSettingTests {

    @Test("초기 일정 글자 크기는 8pt 다")
    func initial_eventTextSizeIsEight() {
        // given
        let setting = WeekEventsStyleSetting.initial

        // when + then
        #expect(setting.eventTextSize == 8)
        #expect(setting.eventTextSizeRange == 8...10)
    }

    @Test("글자 크기가 없는 옛 저장값은 8pt 로 읽힌다")
    func decode_withoutEventTextSize_fallsBackToInitial() throws {
        // when
        let setting = try self.decoded(#"{ "showWeekDayHeader": false }"#)

        // then
        #expect(setting.showWeekDayHeader == false)
        #expect(setting.eventTextSize == 8)
    }

    @Test("범위 밖 글자 크기는 8~10pt 안으로 잘린다", arguments: [
        (3, 8), (20, 10), (9, 9)
    ])
    func decode_outOfRangeEventTextSize_clampsToRange(stored: Int, expected: Int) throws {
        // when
        let setting = try self.decoded(#"{ "eventTextSize": \#(stored) }"#)

        // then
        #expect(setting.eventTextSize == expected)
    }
}
