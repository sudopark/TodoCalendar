//
//  EventDetailSceneSnapshots.swift
//  EventDetailScene
//
//  Created by sudo.park on 7/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import EventDetailScene


final class EventDetailSceneSnapshots: XCTestCase {

    private let start: TimeInterval = 1_751_900_400
    private let end: TimeInterval = 1_751_904_000

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_eventDetail() {
        captureSnapshotPair(named: "eventDetail", layout: .fullScreen) { theme in
            let state = EventDetailViewState()
            state.eventDetailTypeModel = .makeCase(true)
            state.selectedTag = .init(.default, "default", "#ff00ff")
            state.selectedTime = .period(
                .init(self.start, .current), .init(self.end, .current)
            )
            state.selectedRepeat = "some repeat"
            state.selectedPlace = .customPlace("경복궁")
            return EventDetailView()
                .environment(state)
                .environment(EventDetailViewEventHandlers())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_googleEventDetail() {
        captureSnapshotPair(named: "googleEventDetail", layout: .fullScreen) { theme in
            let appearance = self.makeAppearance(theme)
            let colors = GoogleCalendar.Colors(
                ownerId: "snapshot@google.com",
                calendars: ["colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")],
                events: ["colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")]
            )
            appearance.googleCalendarColors[colors.ownerId] = colors
            let state = GoogleCalendarEventDetailViewState()
            state.eventName = "google calendar event"
            state.timeText = .period(.init(self.start, .current), .init(self.end, .current))
            state.ddayText = "D+3"
            state.repeatOptionText = "repeat option"
            state.location = "location text"
            state.calendarModel = .init(calenarId: "some", name: "some@calendar.com")
            return GoogleCalendarEventDetailView()
                .environment(state)
                .environment(GoogleCalendarEventDetailViewEventHandler())
                .environment(appearance)
        }
    }

    @MainActor
    func test_appleEventDetail() {
        captureSnapshotPair(named: "appleEventDetail", layout: .fullScreen) { theme in
            let state = AppleCalendarEventDetailViewState()
            state.eventName = "apple calendar event"
            state.timeText = .period(.init(self.start, .current), .init(self.end, .current))
            state.ddayText = "D-1"
            return AppleCalendarEventDetailView()
                .environment(state)
                .environment(AppleCalendarEventDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_doneTodoDetail() {
        captureSnapshotPair(named: "doneTodoDetail", layout: .fullScreen) { theme in
            let state = DoneTodoDetailViewState()
            state.name = "done todo"
            state.tag = .init(DefaultEventTag.default("some"))
            state.timeModel = .init(doneTime: "20:30", eventTime: .at(.init(self.start, .current)))
            state.notificationOptions = "notifications"
            state.placeModel = .landmark(
                .init(name: "경복궁", coordinate: .init(37.579871, 126.977051), address: "대한민국 종로")
            )
            return DoneTodoDetailView()
                .environment(state)
                .environment(DoneTodoDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    // MARK: - Selections / Dialogs / HolidayDetail / GuideView (#674 Phase 4 픽스처 갭)

    @MainActor
    func test_selectEventTag() {
        captureSnapshotPair(named: "selectEventTag", layout: .fullScreen) { theme in
            let state = SelectEventTagViewState()
            state.tags = [
                .init(.init(.default, "default", "#ff00ff")),
                .init(.init(.custom("some"), "some", "#00ffdd")),
                .init(.init(.custom("some1"), "some1", "#00ffdd")),
            ]
            state.selectedTagId = .custom("some")
            return SelectEventTagView()
                .environment(state)
                .environment(SelectEventTagViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_selectEventNotificationTime() {
        captureSnapshotPair(named: "selectEventNotificationTime", layout: .fullScreen) { theme in
            let state = SelectEventNotificationTimeViewState()
            state.defaultTimeOptions = [
                .init(option: .atTime),
                .init(option: .before(seconds: 60)),
                .init(option: .before(seconds: 60 * 5))
            ]
            state.customTimeOptions = [
                .init(option: .custom(
                    .init(year: 2025, month: 7, day: 10, hour: 12, minute: 30, second: 1)
                ))!
            ]
            state.suggestCustomOptionTime = Date(timeIntervalSince1970: self.start)
            state.notificaitonPermissionDenied = true
            return SelectEventNotificationTimeView()
                .environment(state)
                .environment(SelectEventNotificationTimeViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_selectEventRepeatOption() {
        captureSnapshotPair(named: "selectEventRepeatOption", layout: .fullScreen) { theme in
            let state = SelectEventRepeatOptionViewState()
            let fixedDate = Date(timeIntervalSince1970: self.start)
            state.repeatStartTimeText = fixedDate.text(
                "eventDetail.repeating.starttime:form".localized(),
                timeZone: TimeZone(identifier: "Asia/Seoul")!
            )
            let selectedOption = SelectRepeatingOptionModel("option2", nil)
            state.optionList = [
                [.init("some", nil)],
                [.init("option1", nil), selectedOption, .init("option3", nil)],
            ]
            state.selectedOptionId = selectedOption.id
            return SelectEventRepeatOptionView()
                .environment(state)
                .environment(SelectEventRepeatOptionViewEventHandlers())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_selectMapAppDialog() {
        captureSnapshotPair(named: "selectMapAppDialog", layout: .fullScreen) { theme in
            let appearance = self.makeAppearance(theme)
            let state = SelectMapAppDialogViewState()
            state.supportMapApps = [.apple, .google]
            return ZStack {
                appearance.colorSet.bg1.asColor.ignoresSafeArea()
                SelectMapAppDialogView()
                    .environment(state)
                    .environment(SelectMapAppDialogViewEventHandler())
                    .environment(appearance)
            }
        }
    }

    @MainActor
    func test_holidayEventDetail() {
        captureSnapshotPair(named: "holidayEventDetail", layout: .fullScreen) { theme in
            let state = HolidayEventDetailViewState()
            state.name = "삼일절"
            state.dateText = "2025년 3월 1일 금요일"
            state.ddayText = "D-Day"
            return HolidayEventDetailView()
                .environment(state)
                .environment(HolidayEventDetailViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_todoEventGuide() {
        captureSnapshotPair(named: "todoEventGuide", layout: .fullScreen) { theme in
            let appearance = self.makeAppearance(theme)
            return ZStack {
                appearance.colorSet.bg1.asColor.ignoresSafeArea()
                TodoEventGuideView(appearance: appearance)
            }
        }
    }

    @MainActor
    func test_foremostEventGuide() {
        captureSnapshotPair(named: "foremostEventGuide", layout: .fullScreen) { theme in
            let appearance = self.makeAppearance(theme)
            return ZStack {
                appearance.colorSet.bg1.asColor.ignoresSafeArea()
                ForemostEventGuideView(appearance: appearance)
            }
        }
    }
}
