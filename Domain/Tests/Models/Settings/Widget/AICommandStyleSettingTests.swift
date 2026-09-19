//
//  AICommandStyleSettingTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct AICommandStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> AICommandStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(AICommandStyleSetting.self, from: data)
    }
}


extension AICommandStyleSettingTests {

    @Test("초기값은 표시 항목을 전부 보여준다")
    func initial_showsEveryItem() {
        // given
        let setting = AICommandStyleSetting.initial

        // when + then
        #expect(setting.showExplain == true)
    }

    @Test("표시 항목을 인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func encodeAndDecode_keepAllDisplayItems() throws {
        // given
        let setting = AICommandStyleSetting.initial
            |> \.showExplain .~ false

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(AICommandStyleSetting.self, from: data)

        // then
        #expect(restored.showExplain == false)
    }

    @Test("모르는 키가 섞여 있어도 알려진 항목만 읽는다")
    func decodeUnknownKey_isIgnored() throws {
        // when
        let setting = try self.decoded("{ \"showExplain\": false, \"legacyItem\": true }")

        // then
        #expect(setting.showExplain == false)
    }

    @Test("항목이 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == AICommandStyleSetting.initial)
    }
}
