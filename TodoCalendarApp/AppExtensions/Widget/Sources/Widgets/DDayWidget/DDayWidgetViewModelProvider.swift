//
//  DDayWidgetViewModelProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - DDayWidgetViewModel

struct DDayWidgetViewModel: Sendable {

    let eventTitle: String
    let ddayText: String
    let targetDateText: String
    var refreshAfter: Date?
    var widgetSetting: WidgetAppearanceSettings = .init()

    static var sample: Self {
        return .init(
            eventTitle: "widget.dday.sample::title".localized(),
            ddayText: "D-14",
            targetDateText: DDayTargetDateFormatter.text(
                of: .at(Date().timeIntervalSince1970 + 3600 * 24 * 14), in: .current
            )
        )
    }

    static func noTarget() -> Self {
        return .init(
            eventTitle: "widget.dday::noTarget".localized(),
            ddayText: "–",
            targetDateText: ""
        )
    }
}


// MARK: - DDayWidgetViewModelProvider

final class DDayWidgetViewModelProvider {

    private let eventFetchUsecase: any CalendarEventFetchUsecase
    private let calendarSettingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository

    init(
        eventFetchUsecase: any CalendarEventFetchUsecase,
        calendarSettingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository
    ) {
        self.eventFetchUsecase = eventFetchUsecase
        self.calendarSettingRepository = calendarSettingRepository
        self.appSettingRepository = appSettingRepository
    }
}

extension DDayWidgetViewModelProvider {

    func getDDayModel(
        for now: Date, target: DDayTargetEventId?
    ) async throws -> DDayWidgetViewModel {

        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let refreshAfter = Self.nextMidnight(after: now, in: timeZone)

        guard let target,
              let event = try await self.eventFetchUsecase.fetchDDayTargetEvent(target, after: now)
        else {
            return DDayWidgetViewModel.noTarget()
                |> \.refreshAfter .~ refreshAfter
                |> \.widgetSetting .~ setting
        }

        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let targetDate = Date(
            timeIntervalSince1970: event.time.rangeWithShifttingifNeed(on: timeZone).lowerBound
        )
        let interval = calendar.diffDays(now, targetDate) ?? 0

        return DDayWidgetViewModel(
            eventTitle: event.name,
            ddayText: DDayText(interval).text,
            targetDateText: DDayTargetDateFormatter.text(of: event.time, in: timeZone)
        )
        |> \.refreshAfter .~ refreshAfter
        |> \.widgetSetting .~ setting
    }

    private static func nextMidnight(after now: Date, in timeZone: TimeZone) -> Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(3600)
    }
}
