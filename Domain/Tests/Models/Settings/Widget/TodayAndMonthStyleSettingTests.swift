//
//  TodayAndMonthStyleSettingTests.swift
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


struct TodayAndMonthStyleSettingTests {

    private func decoded(_ jsonText: String) throws -> TodayAndMonthStyleSetting {
        let data = try #require(jsonText.data(using: .utf8))
        return try JSONDecoder().decode(TodayAndMonthStyleSetting.self, from: data)
    }
}


extension TodayAndMonthStyleSettingTests {

    @Test("저장값이 비어 있으면 두 절반 모두 초기값이다")
    func decode_whenEmpty_isInitial() throws {
        // when
        let setting = try self.decoded("{ }")

        // then
        #expect(setting == TodayAndMonthStyleSetting.initial)
    }

    @Test("절반 안쪽 항목이 빠져도 나머지는 저장값, 빠진 항목은 초기값이다")
    func decode_whenFieldMissing_fillsInitial() throws {
        // when
        let setting = try self.decoded("{ \"month\": { \"showMonthName\": false } }")

        // then
        #expect(setting.month.showMonthName == false)
        #expect(setting == (TodayAndMonthStyleSetting.initial |> \.month.showMonthName .~ false))
    }

    @Test("인코딩했다가 디코딩해도 끈 항목이 그대로 남는다")
    func roundTrip_keepsValues() throws {
        // given
        let setting = TodayAndMonthStyleSetting.initial |> \.month .~ (MonthStyleSetting.initial |> \.showMonthName .~ false)

        // when
        let data = try JSONEncoder().encode(setting)
        let restored = try JSONDecoder().decode(TodayAndMonthStyleSetting.self, from: data)

        // then
        #expect(restored.month.showMonthName == false)
    }

    @Test("하위 payload 를 받으면 그 타입의 필드만 갈아 끼운다")
    func replacingPart_setsMatchingField() {
        // given
        let part = MonthStyleSetting.initial |> \.showMonthName .~ false

        // when
        let replaced = TodayAndMonthStyleSetting.initial.replacingPart(part)

        // then
        #expect(replaced.month.showMonthName == false)
    }

    @Test("어느 필드와도 타입이 안 맞는 payload 는 무시한다")
    func replacingPart_whenTypeMismatches_keepsSelf() {
        // given
        let part = ForemostStyleSetting.initial |> \.showTypeLabel .~ false

        // when
        let replaced = TodayAndMonthStyleSetting.initial.replacingPart(part)

        // then
        #expect(replaced == TodayAndMonthStyleSetting.initial)
    }

    @Test("Today 절반을 갈아도 Month 절반은 그대로다")
    func replacingPart_today_keepsMonth() {
        // given
        let base = TodayAndMonthStyleSetting.initial |> \.month.showMonthName .~ false
        let today = TodayStyleSetting.initial |> \.showTimeZone .~ false

        // when
        let replaced = base.replacingPart(today)

        // then
        #expect(replaced.today.showTimeZone == false)
        #expect(replaced.month.showMonthName == false)
    }

    @Test("Month 절반을 갈아도 Today 절반은 그대로다")
    func replacingPart_month_keepsToday() {
        // given
        let base = TodayAndMonthStyleSetting.initial |> \.today.showTimeZone .~ false
        let month = MonthStyleSetting.initial |> \.highlightToday .~ false

        // when
        let replaced = base.replacingPart(month)

        // then
        #expect(replaced.month.highlightToday == false)
        #expect(replaced.today.showTimeZone == false)
    }
}
