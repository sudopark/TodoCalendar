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
import CommonPresentation
import SnapshotTestHelpKit

@testable import EventDetailScene


final class EventDetailSceneSnapshots: XCTestCase {

    // 고정 epoch — Date() 사용 시 재기록마다 라벨이 달라져 git 비교가 무효화된다
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
            // MKMapView(LandmarkMapView) 라이브 렌더링은 크래시·타일 비결정성 → customPlace로 고정
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
}
