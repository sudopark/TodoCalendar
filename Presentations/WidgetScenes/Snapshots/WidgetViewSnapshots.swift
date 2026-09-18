//
//  WidgetViewSnapshots.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Prelude
import Optics
import Domain
import SnapshotTestHelpKit

@testable import WidgetScenes


final class WidgetViewSnapshots: XCTestCase {

    // iPhone 기준 위젯 캔버스 규격 — 확장 WidgetCatalogSnapshots 와 같은 값이다
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

    /// `.sample` 은 dateText 를 실행 시각으로 만들어 날이 바뀌면 png 가 달라진다.
    private func fixedDDayModel(
        background: WidgetAppearanceSettings.Background = .system
    ) -> DDayWidgetViewModel {
        return DDayWidgetViewModel(
            eventTitle: "Team workshop",
            ddayText: "D-14",
            dateText: "Mar 15, 2027",
            timeText: "",
            repeatText: ""
        )
        |> \.widgetSetting .~ (WidgetAppearanceSettings() |> \.background .~ background)
    }

    @MainActor
    private func capture<V: View>(
        _ name: String,
        canvas: CGSize,
        plate: AnyShapeStyle = AnyShapeStyle(.background),
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
                    .fill(plate)
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
    func test_eventListView() {
        self.capture("event-list", canvas: WidgetCanvas.large) {
            EventListView(model: .sample(size: .large)) { _ in AnyView(EmptyView()) }
        }
    }

    @MainActor
    func test_ddaySmallWidgetView() {
        self.capture("dday-small", canvas: WidgetCanvas.small) {
            DDaySmallWidgetView(model: self.fixedDDayModel())
        }
    }

    @MainActor
    func test_ddayMediumWidgetView() {
        self.capture("dday-medium", canvas: WidgetCanvas.medium) {
            DDayMediumWidgetView(model: self.fixedDDayModel())
        }
    }

    /// 확장은 같은 배경색으로 판(`containerBackground`)까지 칠한다 — 글자색이 그 판을 따라오는지 본다.
    @MainActor
    func test_ddaySmallWidgetView_onDarkCustomBackground() {
        let background = WidgetAppearanceSettings.Background.custom(hex: "#101820")
        self.capture(
            "dday-small-darkBackground",
            canvas: WidgetCanvas.small,
            plate: WidgetBackgroundStyle(background).shape
        ) {
            DDaySmallWidgetView(model: self.fixedDDayModel(background: background))
        }
    }

    @MainActor
    func test_ddayMediumWidgetView_onDarkCustomBackground() {
        let background = WidgetAppearanceSettings.Background.custom(hex: "#101820")
        self.capture(
            "dday-medium-darkBackground",
            canvas: WidgetCanvas.medium,
            plate: WidgetBackgroundStyle(background).shape
        ) {
            DDayMediumWidgetView(model: self.fixedDDayModel(background: background))
        }
    }
}
