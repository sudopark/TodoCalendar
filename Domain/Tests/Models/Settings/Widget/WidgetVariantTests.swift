//
//  WidgetVariantTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


private struct OtherStyleSetting: WidgetStyleSetting {

    var isOn: Bool

    static let initial = OtherStyleSetting(isOn: true)
}


struct WidgetVariantTests {

    @Test("꾸미기 대상이 아닌 변형은 payload 타입을 갖지 않는다")
    func settingType_onlyCustomizableVariantHasOne() {
        // given
        let variants = WidgetVariant.allCases

        // when
        let variantsHavingType = variants.filter { $0.settingType != nil }

        // then
        #expect(variantsHavingType == [.todaySummarySmall])
    }

    @Test("변형이 내는 초기 설정은 그 payload 타입의 초기값이다")
    func initialSetting_isPayloadTypeInitial() {
        // given
        let today = WidgetVariant.todaySummarySmall

        // when + then
        #expect(today.initialSetting as? TodayStyleSetting == TodayStyleSetting.initial)
        #expect(WidgetVariant.monthSmall.initialSetting == nil)
    }

    @Test("변형은 자기 payload 타입만 자기 설정으로 본다")
    func isOwnSetting_onlyForItsPayloadType() {
        // given
        let today = WidgetVariant.todaySummarySmall

        // when + then
        #expect(today.isOwnSetting(TodayStyleSetting.initial) == true)
        #expect(today.isOwnSetting(OtherStyleSetting.initial) == false)
        #expect(WidgetVariant.monthSmall.isOwnSetting(TodayStyleSetting.initial) == false)
    }

    @Test("payload 타입이 다르면 같은 설정으로 보지 않는다")
    func isSameSetting_whenPayloadTypeDiffers_returnsFalse() {
        // given
        let setting = TodayStyleSetting.initial
        let changed = TodayStyleSetting(
            showHolidayName: false, showTimeZone: true, showMonthYear: true,
            showTotalCount: true, showTodoCount: true, showScheduleCount: true
        )

        // when + then
        #expect(setting.isSame(setting) == true)
        #expect(setting.isSame(changed) == false)
        #expect(setting.isSame(OtherStyleSetting.initial) == false)
    }
}
