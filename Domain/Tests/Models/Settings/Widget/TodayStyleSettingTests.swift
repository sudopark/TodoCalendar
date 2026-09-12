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

    @Test("표시 항목 다섯을 인코딩했다가 디코딩해도 값이 유지된다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = TodayStyleSetting()
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

    @Test("표시 항목이 늘기 전에 저장된 payload 도 디코딩되고 새 항목은 미지정이다")
    func decodeLegacyPayload_newItemsAreNotSpecified() throws {
        // given
        let legacyText = """
        { "showHolidayName": true }
        """

        // when
        let setting = try self.decoded(legacyText)

        // then
        #expect(setting.showHolidayName == true)
        #expect(setting.showTimeZone == nil)
        #expect(setting.showTotalCount == nil)
        #expect(setting.showTodoCount == nil)
        #expect(setting.showScheduleCount == nil)
    }
}
