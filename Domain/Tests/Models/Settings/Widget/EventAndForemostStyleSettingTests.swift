//
//  EventAndForemostStyleSettingTests.swift
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


struct EventAndForemostStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> EventAndForemostStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(EventAndForemostStyleSetting.self, from: data)
    }
}


extension EventAndForemostStyleSettingTests {

    @Test("저장값이 비어 있으면 두 절반 모두 초기값이다")
    func decode_whenEmpty_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == EventAndForemostStyleSetting.initial)
    }

    @Test("절반 안쪽 항목이 빠져도 나머지는 저장값, 빠진 항목은 초기값이다")
    func decode_whenFieldMissing_fillsInitial() throws {
        // when
        let setting = try self.decoded("{ \"foremost\": { \"showTypeLabel\": false } }")

        // then
        #expect(setting.foremost.showTypeLabel == false)
        #expect(setting == (EventAndForemostStyleSetting.initial |> \.foremost.showTypeLabel .~ false))
    }

    @Test("인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func roundTrip_keepsValues() throws {
        // given
        let setting = EventAndForemostStyleSetting.initial |> \.foremost .~ (ForemostStyleSetting.initial |> \.showTypeLabel .~ false)

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(EventAndForemostStyleSetting.self, from: data)

        // then
        #expect(restored.foremost.showTypeLabel == false)
    }

    @Test("하위 payload 를 받으면 그 타입의 필드만 갈아 끼운다")
    func replacingPart_setsMatchingField() {
        // given
        let part = ForemostStyleSetting.initial |> \.showTypeLabel .~ false

        // when
        let replaced = EventAndForemostStyleSetting.initial.replacingPart(part)

        // then
        #expect(replaced.foremost.showTypeLabel == false)
    }

    @Test("어느 필드와도 타입이 안 맞는 payload 는 무시한다")
    func replacingPart_whenTypeMismatches_keepsSelf() {
        // given
        let part = MonthStyleSetting.initial |> \.showMonthName .~ false

        // when
        let replaced = EventAndForemostStyleSetting.initial.replacingPart(part)

        // then
        #expect(replaced == EventAndForemostStyleSetting.initial)
    }
}
