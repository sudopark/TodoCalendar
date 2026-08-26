//
//  EventDetailSceneCatalogSnapshots.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import TestDoubles
import SnapshotTestHelpKit

@testable import EventDetailScene


final class EventDetailSceneCatalogSnapshots: XCTestCase {

    private let start: TimeInterval = 1_773_282_600     // 2026-03-12 09:30 KST
    private let end: TimeInterval = 1_773_288_000       // 2026-03-12 11:00 KST

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_eventDetail() {
        captureSnapshotPair(
            named: "eventDetail", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = EventDetailViewState()
            state.eventDetailTypeModel = .todoCase()
            state.enterName = "catalog.event::design_review".catalogLocalized()
            state.selectedTag = .init(.default, "eventTag.defaults.default::name".localized(), "#088CDA")
            state.selectedTime = .period(
                .init(self.start, .current), .init(self.end, .current)
            )
            state.selectedRepeat = "eventDetail.repeating.everySomeWeek:title".localized(with: 2)
            state.selectedNotificationTimeText = "event_notification_setting::option_title::before_minutes".localized(with: 10)
            state.enterPlaceName = "catalog.place::startup_hub".catalogLocalized()
            state.selectedPlace = .customPlace("catalog.place::startup_hub".catalogLocalized())
            state.memo = "catalog.memo::wireframes".catalogLocalized()
            state.isSavable = true
            return EventDetailView()
                .environment(state)
                .environment(EventDetailViewEventHandlers())
                .environment(self.makeAppearance(theme))
        }
    }

    /// 옵션 목록은 선택 시각(요일·일자)에서 파생되므로 손으로 나열하지 않고
    /// 프로덕션 ViewModel이 만든 목록을 그대로 캡처한다.
    @MainActor
    private func makeRepeatOptionView(_ theme: SnapshotTheme) -> some View {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let viewModel = SelectEventRepeatOptionViewModelImple(
            selectTime: Date(timeIntervalSince1970: self.start),
            previousSelected: nil,
            rruleRepresentableOnly: false,
            calendarSettingUsecase: settingUsecase
        )
        let state = SelectEventRepeatOptionViewState()
        state.bind(viewModel)
        viewModel.prepare()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // 반복을 하나 골라둬야 하단 '반복 종료' 영역이 함께 노출된다
        if let weekly = state.optionList[safe: 1]?[safe: 1] {
            viewModel.selectOption(weekly.id)
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }

        return SelectEventRepeatOptionView()
            .environment(state)
            .environment(SelectEventRepeatOptionViewEventHandlers())
            .environment(self.makeAppearance(theme))
    }

    @MainActor
    func test_repeatOptions() {
        captureSnapshotPair(
            named: "repeatOptions", layout: .fixed(width: 393, height: 1250), snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            self.makeRepeatOptionView(theme)
        }
    }

    @MainActor
    func test_storeRepeatOptions() {
        captureSnapshotPair(
            named: "storeRepeatOptions", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            self.makeRepeatOptionView(theme)
        }
    }
}
