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


/// 합성 위젯은 제 스타일 좌표가 없다 — 하위 위젯군의 기본 스타일을 절반씩 물려받으면
/// 판과 글자색이 서로 다른 배경에서 나와 한쪽이 안 읽힌다.
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

    @Test("두 하위 위젯군의 기본 스타일 배경색이 갈려도 합성 위젯은 한 값으로 그린다")
    func eventAndForemost_whenChildStylesDiffer_usesOneLook() async throws {
        // given
        let provider = EventAndForemostWidgetViewModelProvider(
            eventListViewModelProvider: self.makeEventListProvider(
                styles: self.style(.eventListSmall, background: .custom(hex: "#101820"))
            ),
            foremostEventViewModelProvider: self.makeForemostProvider(
                styles: self.style(.foremostSmall, background: .custom(hex: "#ffffff"))
            )
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.event.look.background == model.foremost.look.background)
    }

    @Test("합성 위젯은 하위 기본 스타일이 아니라 전역 배경색을 따른다")
    func eventAndForemost_ignoresChildStyleBackground() async throws {
        // given
        let provider = EventAndForemostWidgetViewModelProvider(
            eventListViewModelProvider: self.makeEventListProvider(
                styles: self.style(.eventListSmall, background: .custom(hex: "#101820"))
            ),
            foremostEventViewModelProvider: self.makeForemostProvider(styles: [:])
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.event.look.background == .system)
        #expect(model.event.look.appliedStyle == nil)
    }

    @Test("하위 위젯군의 표시 토글도 합성 위젯으로 새지 않는다")
    func eventAndForemost_doesNotInheritChildToggle() async throws {
        // given
        let off = ForemostStyleSetting.initial |> \.showTypeLabel .~ false
        let id = WidgetStyleId(variant: .foremostSmall, style: .default)
        let provider = EventAndForemostWidgetViewModelProvider(
            eventListViewModelProvider: self.makeEventListProvider(styles: [:]),
            foremostEventViewModelProvider: self.makeForemostProvider(
                styles: [id: WidgetStyle(id: id, name: nil, setting: off)]
            )
        )

        // when
        let model = try await provider.getViewModel(self.now)

        // then
        #expect(model.foremost.showsTypeLabel == true)
    }
}
