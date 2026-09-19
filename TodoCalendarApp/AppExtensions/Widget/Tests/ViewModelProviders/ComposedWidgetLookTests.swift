//
//  ComposedWidgetLookTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles
import WidgetScenes

@testable import TodoCalendarAppWidget


/// 합성 위젯은 제 스타일로 그린다 — 하위 위젯군의 스타일은 합성 위젯으로 새지 않는다.
struct ComposedWidgetLookTests {

    private var now: Date { Date(timeIntervalSince1970: 1710374400) }

    private func style(
        _ variant: WidgetVariant, background: WidgetAppearanceSettings.Background
    ) -> [WidgetStyleId: WidgetStyle] {
        let id = WidgetStyleId(variant: variant, style: .default)
        return [
            id: WidgetStyle(
                id: id, name: nil,
                setting: variant.initialSetting ?? TodayStyleSetting.initial,
                background: background
            )
        ]
    }

    private func makeEventListProvider(
        styles: [WidgetStyleId: WidgetStyle]
    ) -> EventListWidgetViewModelProvider {
        return .init(
            targetEventTagIds: nil,
            excludeAllDayEvents: false,
            eventsFetchUsecase: StubCalendarEventsFetchUescase(),
            appSettingRepository: StubAppSettingRepository(),
            calendarSettingRepository: StubCalendarSettingRepository(),
            localeProvider: Locale.current,
            styleRepository: StubWidgetStyleRepository(styles: styles)
        )
    }

    private func makeForemostProvider(
        styles: [WidgetStyleId: WidgetStyle]
    ) -> ForemostEventWidgetViewModelProvider {
        return .init(
            eventFetchUsecase: StubCalendarEventsFetchUescase(),
            calendarSettingRepository: StubCalendarSettingRepository(),
            appSettingRepository: StubAppSettingRepository(),
            localeProvider: Locale.current,
            styleRepository: StubWidgetStyleRepository(styles: styles)
        )
    }
}


extension ComposedWidgetLookTests {

    private func makeProvider(
        childStyles: [WidgetStyleId: WidgetStyle] = [:],
        composedStyles: [WidgetStyleId: WidgetStyle] = [:]
    ) -> EventAndForemostWidgetViewModelProvider {
        return EventAndForemostWidgetViewModelProvider(
            eventListViewModelProvider: self.makeEventListProvider(styles: childStyles),
            foremostEventViewModelProvider: self.makeForemostProvider(styles: childStyles),
            styleRepository: StubWidgetStyleRepository(styles: composedStyles)
        )
    }

    private func composedStyle(
        _ style: WidgetStyleId.Style,
        setting: EventAndForemostStyleSetting = .initial,
        background: WidgetAppearanceSettings.Background? = nil
    ) -> [WidgetStyleId: WidgetStyle] {
        let id = WidgetStyleId(variant: .eventAndForemostMedium, style: style)
        return [id: WidgetStyle(id: id, name: nil, setting: setting, background: background)]
    }

    @Test("합성 위젯은 제 기본 스타일의 배경색으로 두 절반을 그린다")
    func eventAndForemost_usesComposedStyleBackground() async throws {
        // given
        let provider = self.makeProvider(
            childStyles: self.style(.eventListSmall, background: .custom(hex: "#101820"))
                .merging(self.style(.foremostSmall, background: .custom(hex: "#ffffff"))) { $1 },
            composedStyles: self.composedStyle(.default, background: .custom(hex: "#335577"))
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.event.look.background == .custom(hex: "#335577"))
        #expect(model.foremost.look.background == .custom(hex: "#335577"))
    }

    @Test("인스턴스가 고른 합성 스타일의 Foremost 토글을 따른다")
    func eventAndForemost_foremostHalfUsesComposedToggle() async throws {
        // given
        let off = EventAndForemostStyleSetting.initial |> \.foremost.showTypeLabel .~ false
        let provider = self.makeProvider(
            composedStyles: self.composedStyle(.default)
                .merging(self.composedStyle(.custom(id: "picked"), setting: off)) { $1 }
        )

        // when
        let picked = try await provider.getViewModel(self.now, style: .custom(id: "picked"))
        let byDefault = try await provider.getViewModel(self.now)

        // then
        #expect(picked.foremost.showsTypeLabel == false)
        #expect(byDefault.foremost.showsTypeLabel == true)
    }

    @Test("고른 합성 스타일이 지워졌으면 합성 기본 스타일로 내려간다")
    func eventAndForemost_whenPickedStyleRemoved_fallsBackToDefault() async throws {
        // given
        let provider = self.makeProvider(
            composedStyles: self.composedStyle(.default, background: .custom(hex: "#335577"))
        )

        // when
        let model = try await provider.getViewModel(self.now, style: .custom(id: "removed"))

        // then
        #expect(model.event.look.background == .custom(hex: "#335577"))
    }

    @Test("하위 위젯군의 표시 토글과 배경색은 합성 위젯으로 새지 않는다")
    func eventAndForemost_doesNotInheritChildToggle() async throws {
        // given
        let off = ForemostStyleSetting.initial |> \.showTypeLabel .~ false
        let id = WidgetStyleId(variant: .foremostSmall, style: .default)
        let provider = self.makeProvider(
            childStyles: [id: WidgetStyle(id: id, name: nil, setting: off, background: .custom(hex: "#ffffff"))]
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.foremost.showsTypeLabel == true)
        #expect(model.foremost.look.background == .system)
    }

    @Test("합성 스타일이 저장돼 있지 않으면 초기 토글과 전역 배경색이다")
    func composed_whenNoSavedStyle_usesInitialAndGlobal() async throws {
        // given
        let provider = self.makeProvider()

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.foremost.showsTypeLabel == true)
        #expect(model.event.look.appliedStyle == nil)
        #expect(model.event.look.background == .system)
    }
}


// MARK: - Month·Today 절반을 담은 합성 provider

extension ComposedWidgetLookTests {

    private func makeMonthProvider() -> MonthWidgetViewModelProvider {
        return MonthWidgetViewModelProvider(
            calendarUsecase: StubCalendarUsecase(),
            settingRepository: StubCalendarSettingRepository(),
            appSettingRepository: StubAppSettingRepository(),
            holidayFetchUsecase: HolidaysFetchUsecaseImple(
                holidayUsecase: StubHolidayUsecase(), cached: .init()
            ),
            eventFetchUsecase: StubCalendarEventsFetchUescase(),
            styleRepository: StubWidgetStyleRepository(styles: [:])
        )
    }

    private func makeTodayProvider() -> TodayWidgetViewModelProvider {
        return TodayWidgetViewModelProvider(
            eventsFetchusecase: StubCalendarEventsFetchUescase(),
            appSettingRepository: StubAppSettingRepository(),
            calednarSettingRepository: StubCalendarSettingRepository(),
            styleRepository: StubWidgetStyleRepository(styles: [:])
        )
    }

    private func onlyStyle(
        of variant: WidgetVariant, setting: any WidgetStyleSetting
    ) -> StubWidgetStyleRepository {
        let id = WidgetStyleId(variant: variant, style: .default)
        return StubWidgetStyleRepository(
            styles: [id: WidgetStyle(id: id, name: nil, setting: setting)]
        )
    }

    @Test("DoubleMonth 는 제 변형의 스타일을 읽는다")
    func doubleMonth_readsItsOwnVariantStyle() async throws {
        // given
        let provider = DoubleMonthWidgetViewModelProvider(
            settingRepository: StubCalendarSettingRepository(),
            monthViewModelProvider: self.makeMonthProvider(),
            styleRepository: self.onlyStyle(
                of: .doubleMonthMedium,
                setting: DoubleMonthStyleSetting.initial |> \.month.showMonthName .~ false
            )
        )

        // when
        let model = try await provider.getviewModel(self.now)

        // then
        #expect(model.current.style.showMonthName == false)
        #expect(model.next.style.showMonthName == false)
    }

    @Test("EventAndMonth 는 제 변형의 스타일을 읽는다")
    func eventAndMonth_readsItsOwnVariantStyle() async throws {
        // given
        let provider = EventAndMonthWidgetViewModelProvider(
            eventListViewModelProvider: self.makeEventListProvider(styles: [:]),
            monthViewModelProvider: self.makeMonthProvider(),
            styleRepository: self.onlyStyle(
                of: .eventAndMonthMedium,
                setting: EventAndMonthStyleSetting.initial |> \.month.highlightToday .~ false
            )
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.month.style.highlightToday == false)
    }

    @Test("TodayAndMonth 는 제 변형의 스타일을 읽는다")
    func todayAndMonth_readsItsOwnVariantStyle() async throws {
        // given
        let provider = TodayAndMonthWidgetViewModelProvider(
            todayViewModelProvider: self.makeTodayProvider(),
            monthViewModelProvider: self.makeMonthProvider(),
            styleRepository: self.onlyStyle(
                of: .todayAndMonthMedium,
                setting: TodayAndMonthStyleSetting.initial
                    |> \.today.showTimeZone .~ false
                    |> \.month.showWeekDayHeader .~ false
            )
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.today.style.showTimeZone == false)
        #expect(model.month.style.showWeekDayHeader == false)
    }
}
