//
//  WidgetCatalogSnapshots.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import WidgetKit
import Prelude
import Optics
import Domain
import SnapshotTestHelpKit

@testable import TodoCalendarAppWidget


final class WidgetCatalogSnapshots: XCTestCase {

    // iPhone 기준 위젯 캔버스 규격 — WidgetPreviewContext 가 실제 크기를 잡아준다
    private enum WidgetCanvas {
        static let small = CGSize(width: 170, height: 170)
        static let medium = CGSize(width: 364, height: 170)
        static let large = CGSize(width: 364, height: 382)

        /// WidgetKit이 시스템 위젯에 넣는 기본 content margin
        static let contentMargin: CGFloat = 16
        /// 홈 화면 위젯 모서리 곡률
        static let cornerRadius: CGFloat = 22
        /// 둥근 모서리가 잘리지 않도록 카드 바깥에 두는 여백
        static let outerInset: CGFloat = 14
    }

    // 잠금화면 요소 규격 — 시스템이 벽지 위에 직접 얹으므로 카드 여백이 없다
    private enum LockScreenCanvas {
        static let accessoryInline = CGSize(width: 240, height: 26)
        static let accessoryRectangular = CGSize(width: 160, height: 72)
        static let liveActivity = CGSize(width: 360, height: 160)
    }

    @MainActor
    private func capture<V: View>(
        _ name: String,
        family: WidgetFamily,
        canvas: CGSize,
        testName: String = #function,
        @ViewBuilder makeView: @escaping () -> V
    ) {
        let inset = WidgetCanvas.outerInset
        captureSnapshotPair(
            named: name,
            layout: .fixed(
                width: canvas.width + inset * 2,
                height: canvas.height + inset * 2
            ),
            snapshotDirectory: catalogSnapshotDirectory(),
            testName: testName
        ) { _ in
            ZStack {
                Rectangle()
                    .fill(.background)
                makeView()
                    .previewContext(WidgetPreviewContext(family: family))
                    .padding(WidgetCanvas.contentMargin)
            }
            .frame(width: canvas.width, height: canvas.height)
            .clipShape(
                RoundedRectangle(cornerRadius: WidgetCanvas.cornerRadius, style: .continuous)
            )
            .padding(inset)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    @MainActor
    func test_widgetTodayAndNext() {
        self.capture("widget-today-and-next", family: .systemMedium, canvas: WidgetCanvas.medium) {
            TodayAndNextWidgetView(model: TodayAndNextWidgetViewModel.sample())
        }
    }

    @MainActor
    func test_widgetEventList() {
        self.capture("widget-event-list", family: .systemLarge, canvas: WidgetCanvas.large) {
            let model = EventListWidgetViewModel.sample(size: .init(WidgetFamily.systemLarge))
            return EventListWidgetView(
                entry: ResultTimelineEntry(date: Date(), result: .success(model))
            )
        }
    }

    @MainActor
    func test_widgetToday() {
        self.capture("widget-today", family: .systemSmall, canvas: WidgetCanvas.small) {
            TodayWidgetView(
                entry: ResultTimelineEntry(date: Date(), result: .success(TodayWidgetViewModel.sample()))
            )
        }
    }

    @MainActor
    func test_widgetForemost() {
        self.capture("widget-foremost", family: .systemSmall, canvas: WidgetCanvas.small) {
            ForemostEventWidgetView(
                entry: ResultTimelineEntry(
                    date: Date(), result: .success(ForemostEventWidgetViewModel.sample())
                )
            )
        }
    }

    @MainActor
    func test_widgetMonth() {
        self.capture("widget-month", family: .systemLarge, canvas: WidgetCanvas.large) {
            let model = WeekEventsViewModel.sample(.wholeMonth(.current))
            return WeekEventsWidgetView(
                entry: ResultTimelineEntry(date: Date(), result: .success(model))
            )
        }
    }

    // 잠금화면 요소는 홈 화면 위젯과 렌더가 다르다 — 둥근 카드도 불투명 배경도 없고,
    // 시스템이 벽지 위에 vibrancy 로 얹는다. 그래서 합성 단계가 벽지에 올릴 수 있도록
    // 투명 배경으로 찍는다.
    @MainActor
    private func captureLockScreen<V: View>(
        _ name: String,
        canvas: CGSize,
        testName: String = #function,
        @ViewBuilder makeView: @escaping () -> V
    ) {
        captureSnapshotPair(
            named: name,
            layout: .fixed(width: canvas.width, height: canvas.height),
            snapshotDirectory: catalogSnapshotDirectory(),
            testName: testName
        ) { _ in
            makeView()
                .frame(width: canvas.width, height: canvas.height)
                .environment(\.colorScheme, .dark)
        }
    }

    @MainActor
    func test_widgetLockScreenForemost() {
        self.captureLockScreen("lockscreen-foremost", canvas: LockScreenCanvas.accessoryInline) {
            InlineSizeForemostEventView(model: ForemostEventWidgetViewModel.sample())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }

    @MainActor
    func test_widgetLockScreenNext() {
        self.captureLockScreen("lockscreen-next", canvas: LockScreenCanvas.accessoryRectangular) {
            NextEventRectangleWidgetView(
                model: .init(
                    timeText: .init(text: "14:00"),
                    eventTitle: "catalog.event::team_workshop".catalogLocalized()
                )
            )
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        }
    }

    @MainActor
    func test_widgetLockScreenNextRemain() {
        self.captureLockScreen("lockscreen-next-remain", canvas: LockScreenCanvas.accessoryRectangular) {
            NextRemainEventVListiew(
                model: .init(models: [
                    .init(timeText: .init(text: "14:00"), eventTitle: "catalog.event::team_workshop".catalogLocalized()),
                    .init(timeText: .init(text: "16:00"), eventTitle: "catalog.event::dentist".catalogLocalized()),
                    .init(timeText: .init(text: "18:30"), eventTitle: "catalog.event::dinner".catalogLocalized())
                ])
            )
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        }
    }

    @MainActor
    func test_widgetLockScreenLiveActivity() {
        self.captureLockScreen("lockscreen-live-activity", canvas: LockScreenCanvas.liveActivity) {
            // 카운트다운은 now 기준이라 딱 떨어지는 값이면 만들어낸 티가 난다. 표기 시각도
            // 잠금화면 합성이 박는 9:41 에서 그만큼 뒤로 맞춘다 — 로케일 표기는 포매터로
            let eventDate = Date().addingTimeInterval(42 * 60 + 17)
            let displayTime = Calendar.current.date(
                bySettingHour: 10, minute: 23, second: 0, of: Date()
            ) ?? eventDate
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            let attributes = EventCountdownActivityAttributes(target: .todo(id: "sample"))
            let state = EventCountdownActivityAttributes.State(
                eventName: "catalog.event::design_review".catalogLocalized(),
                eventTimeText: timeFormatter.string(from: displayTime),
                tagColorHex: "#2F6FED",
                eventDate: eventDate,
                startDate: eventDate.addingTimeInterval(-75 * 60),
                placeName: "catalog.place::startup_hub".catalogLocalized()
            )
            return EventCountdownLockScreenView(
                model: EventCountdownActivityViewModel(attributes, state),
                isStale: false
            )
        }
    }

    @MainActor
    func test_widgetAICommand() {
        self.capture("widget-ai-command", family: .systemSmall, canvas: WidgetCanvas.small) {
            AICommandShortcutWidgetView()
        }
    }
}
