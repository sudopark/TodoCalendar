//
//  WidgetLookTests.swift
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


struct WidgetLookTests {

    private func makeGlobalSetting(
        _ background: WidgetAppearanceSettings.Background
    ) -> WidgetAppearanceSettings {
        return WidgetAppearanceSettings() |> \.background .~ background
    }

    private func makeStyle(
        setting: any WidgetStyleSetting = TodayStyleSetting.initial,
        background: WidgetAppearanceSettings.Background? = nil
    ) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .default),
            name: nil,
            setting: setting,
            background: background
        )
    }

    @Test("고른 스타일이 없으면 전역 배경색을 쓴다")
    func background_whenNoAppliedStyle_usesGlobal() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: nil
        )

        // when + then
        #expect(look.background == .custom(hex: "#111111"))
    }

    @Test("고른 스타일이 배경색을 가지면 그 색을 쓴다")
    func background_whenAppliedStyleHasOne_usesIt() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: self.makeStyle(background: .custom(hex: "#222222"))
        )

        // when + then
        #expect(look.background == .custom(hex: "#222222"))
    }

    @Test("고른 스타일이 배경색을 안 가지면 전역 배경색을 쓴다")
    func background_whenAppliedStyleHasNone_usesGlobalNotStyleDefault() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: self.makeStyle(background: nil)
        )

        // when + then
        #expect(look.background == .custom(hex: "#111111"))
    }

    @Test("고른 스타일이 시스템 배경을 걸면 전역이 사용자 색이어도 시스템이 이긴다")
    func background_whenAppliedStyleIsSystem_beatsCustomGlobal() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: self.makeStyle(background: .system)
        )

        // when + then
        #expect(look.background == .system)
    }

    @Test("고른 스타일이 없으면 표시 설정은 초기값이다")
    func setting_whenNoAppliedStyle_isInitial() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.system), appliedStyle: nil
        )

        // when
        let setting: TodayStyleSetting = look.setting()

        // then
        #expect(setting == TodayStyleSetting.initial)
    }

    @Test("고른 스타일의 payload 타입이 다르면 표시 설정은 초기값이다")
    func setting_whenTypeMismatches_isInitial() {
        // given
        let saved = MonthStyleSetting.initial |> \.showMonthName .~ false
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.system),
            appliedStyle: self.makeStyle(setting: saved)
        )

        // when
        let setting: TodayStyleSetting = look.setting()

        // then
        #expect(setting == TodayStyleSetting.initial)
    }

    @Test("고른 스타일의 payload 타입이 맞으면 저장된 표시 설정을 쓴다")
    func setting_whenTypeMatches_returnsSavedOne() {
        // given
        let saved = TodayStyleSetting.initial |> \.showTimeZone .~ false
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.system),
            appliedStyle: self.makeStyle(setting: saved)
        )

        // when
        let setting: TodayStyleSetting = look.setting()

        // then
        #expect(setting.showTimeZone == false)
        #expect(setting == saved)
    }
}


// MARK: - 합성 위젯의 절반

extension WidgetLookTests {

    private func makeComposedStyle(
        _ setting: TodayAndMonthStyleSetting,
        background: WidgetAppearanceSettings.Background?
    ) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: .todayAndMonthMedium, style: .custom(id: "composed")),
            name: "composed",
            setting: setting,
            background: background
        )
    }

    @Test("합성 스타일이 없으면 절반도 스타일이 없어 초기값과 전역 배경색을 쓴다")
    func part_whenNoAppliedStyle_hasNoAppliedStyle() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: nil
        )

        // when
        let part = look.part(\TodayAndMonthStyleSetting.month)

        // then
        #expect(part.appliedStyle == nil)
        #expect(part.background == .custom(hex: "#111111"))
    }

    @Test("절반은 합성 payload 에서 keyPath 로 고른 하위 payload 를 읽는다")
    func part_takesChildSettingByKeyPath() {
        // given
        let composed = TodayAndMonthStyleSetting.initial
            |> \.month.showMonthName .~ false
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.system),
            appliedStyle: self.makeComposedStyle(composed, background: nil)
        )

        // when
        let month: MonthStyleSetting = look.part(\TodayAndMonthStyleSetting.month).setting()
        let today: TodayStyleSetting = look.part(\TodayAndMonthStyleSetting.today).setting()

        // then
        #expect(month.showMonthName == false)
        #expect(today == TodayStyleSetting.initial)
    }

    @Test("절반은 합성 스타일의 배경색을 그대로 쓴다")
    func part_keepsComposedBackground() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: self.makeComposedStyle(.initial, background: .custom(hex: "#333333"))
        )

        // when
        let part = look.part(\TodayAndMonthStyleSetting.today)

        // then
        #expect(part.background == .custom(hex: "#333333"))
    }

    @Test("고른 스타일이 그 합성 payload 가 아니면 절반은 스타일 없이 전역을 쓴다")
    func part_whenComposedTypeMismatches_hasNoAppliedStyle() {
        // given
        let look = WidgetLook(
            globalSetting: self.makeGlobalSetting(.custom(hex: "#111111")),
            appliedStyle: self.makeStyle(background: .custom(hex: "#222222"))
        )

        // when
        let part = look.part(\TodayAndMonthStyleSetting.month)

        // then
        #expect(part.appliedStyle == nil)
        #expect(part.background == .custom(hex: "#111111"))
    }
}
