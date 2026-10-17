//
//  DDayWidgetSnapshots.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import WidgetKit
import SnapshotTestHelpKit
import WidgetScenes


/// `snapshotDirectory` 를 안 넘긴다 — `catalogSnapshotDirectory()` 는 gitignore 된 경로라 png 비교가 성립하지 않는다.
final class DDayWidgetSnapshots: XCTestCase {

    private enum WidgetCanvas {
        static let small = CGSize(width: 170, height: 170)
        static let medium = CGSize(width: 364, height: 170)

        static let contentMargin: CGFloat = 16
        static let cornerRadius: CGFloat = 22
        static let outerInset: CGFloat = 14
    }

    private enum LockScreenCanvas {
        static let accessoryCircular = CGSize(width: 76, height: 76)
        static let accessoryRectangular = CGSize(width: 160, height: 72)
        static let accessoryInline = CGSize(width: 240, height: 26)
    }

    /// `.sample` 은 dateText 를 실행 시각으로 만들어 날이 바뀌면 png 가 달라진다.
    private var fixedModel: DDayWidgetViewModel {
        return DDayWidgetViewModel(
            eventTitle: "Team workshop",
            ddayText: "D-14",
            dateText: "Mar 15, 2027",
            timeText: "7:00 AM",
            repeatText: "Every Mon"
        )
    }

    @MainActor
    private func capture<V: View>(
        _ name: String,
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
            testName: testName
        ) { _ in
            ZStack {
                Rectangle()
                    .fill(.background)
                makeView()
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
    private func captureLockScreen<V: View>(
        _ name: String,
        canvas: CGSize,
        testName: String = #function,
        @ViewBuilder makeView: @escaping () -> V
    ) {
        captureSnapshotPair(
            named: name,
            layout: .fixed(width: canvas.width, height: canvas.height),
            testName: testName
        ) { _ in
            makeView()
                .frame(width: canvas.width, height: canvas.height)
        }
    }
}


extension DDayWidgetSnapshots {

    @MainActor
    func test_ddaySmall() {
        self.capture("dday-small", canvas: WidgetCanvas.small) {
            DDaySmallWidgetView(model: self.fixedModel)
        }
    }

    @MainActor
    func test_ddayMedium() {
        self.capture("dday-medium", canvas: WidgetCanvas.medium) {
            DDayMediumWidgetView(model: self.fixedModel)
        }
    }

    @MainActor
    func test_ddayCircular() {
        self.captureLockScreen("dday-circular", canvas: LockScreenCanvas.accessoryCircular) {
            // 엔트리 뷰가 씌우는 구성 그대로 찍는다 — 시스템 배경은 WidgetKit 타입이라 확장에 남는다
            ZStack {
                AccessoryWidgetBackground()
                DDayCircularWidgetView(model: self.fixedModel)
            }
        }
    }

    @MainActor
    func test_ddayRectangular() {
        self.captureLockScreen("dday-rectangular", canvas: LockScreenCanvas.accessoryRectangular) {
            DDayRectangularWidgetView(model: self.fixedModel)
        }
    }

    @MainActor
    func test_ddayInline() {
        self.captureLockScreen("dday-inline", canvas: LockScreenCanvas.accessoryInline) {
            DDayInlineWidgetView(model: self.fixedModel)
        }
    }
}
