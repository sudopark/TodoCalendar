//
//  ComposedWidgetViewModelsTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain

@testable import WidgetScenes


struct ComposedWidgetViewModelsTests {

    private let factory = ComposedWidgetSampleFactory()

    private func makeLook(
        variant: WidgetVariant,
        setting: any WidgetStyleSetting,
        background: WidgetAppearanceSettings.Background? = .custom(hex: "#123456")
    ) -> WidgetLook {
        let id = WidgetStyleId(variant: variant, style: .custom(id: "composed"))
        return WidgetLook(
            globalSetting: WidgetAppearanceSettings() |> \.background .~ .system,
            appliedStyle: WidgetStyle(id: id, name: nil, setting: setting, background: background)
        )
    }
}


extension ComposedWidgetViewModelsTests {

    @Test("DoubleMonth 는 두 달이 합성 스타일의 Month 절반 하나를 같이 따른다")
    func doubleMonth_bothHalvesShareMonthField() throws {
        // given
        let model = try #require(self.factory.doubleMonth())
        let setting = DoubleMonthStyleSetting.initial |> \.month.showMonthName .~ false
        let look = self.makeLook(variant: .doubleMonthMedium, setting: setting)

        // when
        let applied = model.applying(look)

        // then
        #expect(applied.current.style.showMonthName == false)
        #expect(applied.next.style.showMonthName == false)
        #expect(applied.current.look.background == .custom(hex: "#123456"))
        #expect(applied.next.look.background == .custom(hex: "#123456"))
    }

    @Test("EventAndMonth 는 Month 절반이 합성 스타일의 토글을, 이벤트 절반이 같은 판 색을 쓴다")
    func eventAndMonth_monthHalfTakesComposedField() throws {
        // given
        let model = try #require(self.factory.eventAndMonth())
        let setting = EventAndMonthStyleSetting.initial |> \.month.highlightToday .~ false
        let look = self.makeLook(variant: .eventAndMonthMedium, setting: setting)

        // when
        let applied = model.applying(look)

        // then
        #expect(applied.month.style.highlightToday == false)
        #expect(applied.event.look.background == .custom(hex: "#123456"))
        #expect(applied.month.look.background == .custom(hex: "#123456"))
    }

    @Test("EventAndForemost 는 Foremost 절반이 합성 스타일의 라벨 토글을 따른다")
    func eventAndForemost_foremostHalfUsesComposedToggle() {
        // given
        let model = self.factory.eventAndForemost()
        let setting = EventAndForemostStyleSetting.initial |> \.foremost.showTypeLabel .~ false
        let look = self.makeLook(variant: .eventAndForemostMedium, setting: setting)

        // when
        let applied = model.applying(look)

        // then
        #expect(applied.foremost.showsTypeLabel == false)
        #expect(applied.event.look.background == .custom(hex: "#123456"))
        #expect(applied.foremost.look.background == .custom(hex: "#123456"))
    }

    @Test("TodayAndMonth 는 두 절반이 각자의 필드를 읽는다")
    func todayAndMonth_eachHalfTakesItsOwnField() throws {
        // given
        let model = try #require(self.factory.todayAndMonth())
        let setting = TodayAndMonthStyleSetting.initial
            |> \.today.showTimeZone .~ false
            |> \.month.showWeekDayHeader .~ false
        let look = self.makeLook(variant: .todayAndMonthMedium, setting: setting)

        // when
        let applied = model.applying(look)

        // then
        #expect(applied.today.style.showTimeZone == false)
        #expect(applied.today.style.showHolidayName == true)
        #expect(applied.month.style.showWeekDayHeader == false)
        #expect(applied.month.style.showMonthName == true)
    }

    @Test("합성 스타일이 없으면 두 절반 모두 초기값과 전역 배경색을 쓴다")
    func applying_whenNoAppliedStyle_usesInitialAndGlobal() throws {
        // given
        let model = try #require(self.factory.todayAndMonth())
        let look = WidgetLook(
            globalSetting: WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#abcdef"),
            appliedStyle: nil
        )

        // when
        let applied = model.applying(look)

        // then
        #expect(applied.today.style == TodayStyleSetting.initial)
        #expect(applied.month.style == MonthStyleSetting.initial)
        #expect(applied.today.look.background == .custom(hex: "#abcdef"))
        #expect(applied.month.look.background == .custom(hex: "#abcdef"))
    }
}
