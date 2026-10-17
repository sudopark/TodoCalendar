//
//  EventListStyleSettingTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct EventListStyleSettingTests {

    @Test("항목이 없는 payload 는 초기값 그대로다")
    func decodeEmptyPayload_isInitial() throws {
        // given
        let data = try #require("{ }".data(using: .utf8))

        // when
        let setting = try JSONDecoder().decode(EventListStyleSetting.self, from: data)

        // then
        #expect(setting == EventListStyleSetting.initial)
    }

    @Test("인코딩했다가 디코딩해도 초기값 그대로다")
    func encodeAndDecode_roundTrips() throws {
        // given
        let setting = EventListStyleSetting.initial

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(EventListStyleSetting.self, from: data)

        // then
        #expect(restored == setting)
    }

    @Test("필드가 없어도 다른 payload 타입과는 같은 설정으로 보지 않는다")
    func isSame_whenOtherType_returnsFalse() {
        // given
        let setting = EventListStyleSetting.initial

        // when + then
        #expect(setting.isSame(EventListStyleSetting.initial) == true)
        #expect(setting.isSame(AICommandStyleSetting.initial) == false)
    }
}
