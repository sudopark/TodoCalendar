//
//  WidgetViewSnapshots.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
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
    func test_eventListView() {
        self.capture("event-list", canvas: WidgetCanvas.large) {
            EventListView(model: .sample(size: .large)) { _ in AnyView(EmptyView()) }
        }
    }

    @MainActor
    func test_ddaySmallWidgetView() {
        self.capture("dday-small", canvas: WidgetCanvas.small) {
            DDaySmallWidgetView(model: .sample)
        }
    }
}
