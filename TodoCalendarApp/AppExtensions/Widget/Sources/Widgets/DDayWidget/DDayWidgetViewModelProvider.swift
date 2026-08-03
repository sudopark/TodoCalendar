//
//  DDayWidgetViewModelProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


// MARK: - DDayWidgetViewModel

struct DDayWidgetViewModel: Sendable {

    let eventTitle: String
    let ddayText: String
    let dateText: String
    let timeText: String
    let repeatText: String
    var refreshAfter: Date?
    var link: URL?
    var widgetSetting: WidgetAppearanceSettings = .init()

    var isRepeating: Bool {
        return self.repeatText.isEmpty == false
    }

    /// 잠금화면 inline 한 줄. D-n을 앞에 두는 이유 — inline은 폭이 좁아 뒤에서부터 잘리는데,
    /// 제목이 길 때 남은 일수가 사라지면 이 위젯을 둘 이유가 없어진다.
    var lockScreenInlineText: String {
        return [self.ddayText, self.eventTitle].joinedNonEmpty(separator: " · ")
    }

    static var sample: Self {
        return .init(
            eventTitle: "widget.dday.sample::title".localized(),
            ddayText: "D-14",
            dateText: DDayTargetDateFormatter.dateText(
                of: .at(Date().timeIntervalSince1970 + 3600 * 24 * 14), in: .current
            ),
            timeText: "",
            repeatText: ""
        )
    }

    static func noTarget() -> Self {
        return .init(
            eventTitle: "widget.dday::noTarget".localized(),
            ddayText: "–",
            dateText: "",
            timeText: "",
            repeatText: ""
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

    private enum Constant {
        static let fallbackRefreshInterval: TimeInterval = 3600
    }

    func getDDayModel(
        for now: Date, target: DDayTargetEventId?
    ) async throws -> DDayWidgetViewModel {

        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadWidgetAppearanceSetting()
        let refreshAfter = self.nextMidnight(after: now, in: timeZone)

        guard let target,
              let event = try await self.eventFetchUsecase.fetchDDayTargetEvent(target)
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
            dateText: DDayTargetDateFormatter.dateText(of: event.time, in: timeZone),
            timeText: DDayTargetDateFormatter.timeText(of: event.time, in: timeZone),
            repeatText: self.repeatText(event, timeZone)
        )
        |> \.refreshAfter .~ refreshAfter
        |> \.link .~ self.link(for: event, in: timeZone)
        |> \.widgetSetting .~ setting
    }

    /// 일정은 그 회차 상세로, 공휴일은 해당 날짜 선택으로 보낸다.
    /// 공휴일 상세는 Holiday.uuid를 요구하는데 위젯엔 그 값이 없다 — 상세에 날짜·이름·D-day뿐이라
    /// 날짜 선택으로 보내도 정보 손실이 없다.
    private func link(for event: DDayTargetEvent, in timeZone: TimeZone) -> URL? {
        switch event.targetId.kind {
        case .schedule:
            return EventDeepLinkBuilder
                .schedule(id: event.targetId.rawId, time: event.time)
                .build()

        case .holiday:
            let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
            let date = Date(
                timeIntervalSince1970: event.time.rangeWithShifttingifNeed(on: timeZone).lowerBound
            )
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year,
                  let month = components.month,
                  let day = components.day
            else { return nil }
            return CalendarDay(year, month, day).link
        }
    }

    private func repeatText(_ event: DDayTargetEvent, _ timeZone: TimeZone) -> String {
        guard let option = event.repeatOption,
              let startTime = event.repeatStartTime,
              let text = option.summaryText(startTime: startTime, timeZone: timeZone)
        else { return "" }
        return text
    }

    private func nextMidnight(after now: Date, in timeZone: TimeZone) -> Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(Constant.fallbackRefreshInterval)
    }
}
