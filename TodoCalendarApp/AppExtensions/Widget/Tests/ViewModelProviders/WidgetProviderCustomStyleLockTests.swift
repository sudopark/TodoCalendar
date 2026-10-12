//
//  WidgetProviderCustomStyleLockTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import UnitTestHelpKit
import TestDoubles
import WidgetScenes

@testable import TodoCalendarAppWidget


/// 고른 커스텀을 그릴 권한이 없으면 provider 마다 잠김 에러를 삼키지 않고 실패 엔트리로 넘긴다.
struct WidgetProviderCustomStyleLockTests {

    struct LockCase: Sendable, CustomTestStringConvertible {
        let name: String
        let variant: WidgetVariant
        let load: @Sendable (any WidgetStyleFetchUsecase, WidgetStyleId.Style) async throws -> Void

        var testDescription: String { self.name }
    }

    private let picked: WidgetStyleId.Style = .custom(id: "picked")

    private func deniedResolver(_ variant: WidgetVariant) -> any WidgetStyleFetchUsecase {
        let id = WidgetStyleId(variant: variant, style: self.picked)
        let style = WidgetStyle(
            id: id, name: nil, setting: variant.initialSetting ?? TodayStyleSetting.initial
        )
        return StubWidgetStyleRepository(styles: [id: style]).asStyleFetchUsecase(canRender: false)
    }

    @Test(arguments: Self.cases)
    func provider_whenPickedCustomRenderDenied_throwsLocked(_ lockCase: LockCase) async {
        // given
        let resolver = self.deniedResolver(lockCase.variant)

        // when + then
        await #expect(throws: PaidFeatureGateFailReason.self) {
            try await lockCase.load(resolver, self.picked)
        }
    }
}


// MARK: - cases

private struct ProviderFactory {

    let now = Date(timeIntervalSince1970: 1710374400)

    var allowedResolver: any WidgetStyleFetchUsecase {
        return StubWidgetStyleRepository().asStyleFetchUsecase()
    }

    func eventList(_ resolver: any WidgetStyleFetchUsecase) -> EventListWidgetViewModelProvider {
        return .init(
            targetEventTagIds: nil,
            excludeAllDayEvents: false,
            eventsFetchUsecase: StubCalendarEventsFetchUescase(),
            appSettingRepository: StubAppSettingRepository(),
            calendarSettingRepository: StubCalendarSettingRepository(),
            localeProvider: Locale.current,
            styleFetchUsecase: resolver
        )
    }

    func today(_ resolver: any WidgetStyleFetchUsecase) -> TodayWidgetViewModelProvider {
        return .init(
            eventsFetchusecase: StubCalendarEventsFetchUescase(),
            appSettingRepository: StubAppSettingRepository(),
            calednarSettingRepository: StubCalendarSettingRepository(),
            styleFetchUsecase: resolver
        )
    }

    func month(_ resolver: any WidgetStyleFetchUsecase) -> MonthWidgetViewModelProvider {
        return .init(
            calendarUsecase: StubCalendarUsecase(),
            settingRepository: StubCalendarSettingRepository(),
            appSettingRepository: StubAppSettingRepository(),
            holidayFetchUsecase: HolidaysFetchUsecaseImple(
                holidayUsecase: StubHolidayUsecase(), cached: .init()
            ),
            eventFetchUsecase: StubCalendarEventsFetchUescase(),
            styleFetchUsecase: resolver
        )
    }
}

extension WidgetProviderCustomStyleLockTests {

    static var cases: [LockCase] {
        return [
            .init(name: "DDay", variant: .ddaySmall) { resolver, style in
                let factory = ProviderFactory()
                _ = try await DDayWidgetViewModelProvider(
                    eventFetchUsecase: StubCalendarEventsFetchUescase(),
                    calendarSettingRepository: StubCalendarSettingRepository(),
                    appSettingRepository: StubAppSettingRepository(),
                    styleFetchUsecase: resolver
                ).getDDayModel(for: factory.now, target: nil, style: style)
            },
            .init(name: "EventList", variant: .eventListSmall) { resolver, style in
                let factory = ProviderFactory()
                _ = try await factory.eventList(resolver)
                    .getEventListViewModel(for: factory.now, widgetSize: .small, style: style)
            },
            .init(name: "Foremost", variant: .foremostSmall) { resolver, style in
                let factory = ProviderFactory()
                _ = try await ForemostEventWidgetViewModelProvider(
                    eventFetchUsecase: StubCalendarEventsFetchUescase(),
                    calendarSettingRepository: StubCalendarSettingRepository(),
                    appSettingRepository: StubAppSettingRepository(),
                    localeProvider: Locale.current,
                    styleFetchUsecase: resolver
                ).getViewModel(factory.now, style: style)
            },
            .init(name: "Today", variant: .todaySummarySmall) { resolver, style in
                let factory = ProviderFactory()
                _ = try await factory.today(resolver).getTodayViewModel(for: factory.now, style: style)
            },
            .init(name: "TodayAndNext", variant: .todayAndNextMedium) { resolver, style in
                let factory = ProviderFactory()
                _ = try await TodayAndNextWidgetViewModelProvider(
                    targetEventTagIds: nil,
                    excludeAllDayEvents: false,
                    eventsFetchUsecase: StubCalendarEventsFetchUescase(),
                    calendarSettingRepository: StubCalendarSettingRepository(),
                    appSettingRepository: StubAppSettingRepository(),
                    localeProvider: Locale.current,
                    styleFetchUsecase: resolver
                ).getViewModel(for: factory.now, style: style)
            },
            .init(name: "WeekEvents", variant: .oneWeekEvents) { resolver, style in
                let factory = ProviderFactory()
                _ = try await WeekEventsWidgetViewModelProvider(
                    calendarUsecase: StubCalendarUsecase(),
                    eventFetchUsecase: StubCalendarEventsFetchUescase(),
                    settingRepository: StubCalendarSettingRepository(),
                    appSettingRepository: StubAppSettingRepository(),
                    styleFetchUsecase: resolver
                ).getWeekEventsModel(from: factory.now, range: .weeks(count: 1), style: style)
            },
            .init(name: "DoubleMonth", variant: .doubleMonthMedium) { resolver, style in
                let factory = ProviderFactory()
                _ = try await DoubleMonthWidgetViewModelProvider(
                    settingRepository: StubCalendarSettingRepository(),
                    monthViewModelProvider: factory.month(factory.allowedResolver),
                    styleFetchUsecase: resolver
                ).getviewModel(factory.now, style: style)
            },
            .init(name: "EventAndMonth", variant: .eventAndMonthMedium) { resolver, style in
                let factory = ProviderFactory()
                _ = try await EventAndMonthWidgetViewModelProvider(
                    eventListViewModelProvider: factory.eventList(factory.allowedResolver),
                    monthViewModelProvider: factory.month(factory.allowedResolver),
                    styleFetchUsecase: resolver
                ).getViewModel(factory.now, style: style)
            },
            .init(name: "TodayAndMonth", variant: .todayAndMonthMedium) { resolver, style in
                let factory = ProviderFactory()
                _ = try await TodayAndMonthWidgetViewModelProvider(
                    todayViewModelProvider: factory.today(factory.allowedResolver),
                    monthViewModelProvider: factory.month(factory.allowedResolver),
                    styleFetchUsecase: resolver
                ).getViewModel(factory.now, style: style)
            }
        ]
    }
}
