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

    @MainActor
    func test_widgetAICommand() {
        self.capture("widget-ai-command", family: .systemSmall, canvas: WidgetCanvas.small) {
            AICommandShortcutWidgetView()
        }
    }
}
