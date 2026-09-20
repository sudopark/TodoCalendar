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
        background: WidgetAppearanceSettings.Background = .system,
        photo: WidgetStylePhoto? = nil
    ) -> DDayWidgetViewModel {
        return DDayWidgetViewModel(
            eventTitle: "Team workshop",
            ddayText: "D-14",
            dateText: "Mar 15, 2027",
            timeText: "",
            repeatText: ""
        )
        |> \.look .~ .init(
            globalSetting: WidgetAppearanceSettings() |> \.background .~ background,
            appliedStyle: photo.map {
                WidgetStyle(
                    id: .init(variant: .ddaySmall, style: .default),
                    name: nil, setting: DDayStyleSetting.initial, photo: $0
                )
            }
        )
    }

    @MainActor
    private func capture<V: View>(
        _ name: String,
        canvas: CGSize,
        plate: AnyShapeStyle = AnyShapeStyle(.background),
        testName: String = #function,
        @ViewBuilder makeView: @escaping () -> V
    ) {
        self.capture(
            name, canvas: canvas,
            plateView: { Rectangle().fill(plate) },
            testName: testName, makeView: makeView
        )
    }

    @MainActor
    private func capture<P: View, V: View>(
        _ name: String,
        canvas: CGSize,
        @ViewBuilder plateView: @escaping () -> P,
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
                plateView()
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

    @MainActor
    func test_ddaySmallWidgetView_photoBackground() {
        let model = self.fixedDDayModel(
            photo: GradientPhotoFixture(WidgetCanvas.small).photo
        )
        self.capture(
            "dday-small-photoBackground",
            canvas: WidgetCanvas.small,
            plateView: {
                WidgetBackgroundView(
                    look: model.look,
                    in: RoundedRectangle(
                        cornerRadius: WidgetCanvas.cornerRadius, style: .continuous
                    )
                )
            }
        ) {
            DDaySmallWidgetView(model: model)
        }
    }

    @MainActor
    func test_ddayMediumWidgetView_photoBackground() {
        let model = self.fixedDDayModel(
            photo: GradientPhotoFixture(WidgetCanvas.medium).photo
        )
        self.capture(
            "dday-medium-photoBackground",
            canvas: WidgetCanvas.medium,
            plateView: {
                WidgetBackgroundView(
                    look: model.look,
                    in: RoundedRectangle(
                        cornerRadius: WidgetCanvas.cornerRadius, style: .continuous
                    )
                )
            }
        ) {
            DDayMediumWidgetView(model: model)
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


// MARK: - 표시 토글 OFF

extension WidgetViewSnapshots {

    private func allOffLook<Item: WidgetStyleItem>(
        _ variant: WidgetVariant, _ item: Item.Type
    ) -> WidgetLook {
        let setting = Item.allCases.reduce(Item.Setting.initial) { acc, item in
            acc |> item.settingKeyPath .~ false
        }
        return WidgetLook(
            globalSetting: WidgetAppearanceSettings(),
            appliedStyle: WidgetStyle(
                id: .init(variant: variant, style: .default), name: nil, setting: setting
            )
        )
    }

    @MainActor
    func test_monthView_allTogglesOff() {
        let look = self.allOffLook(.monthSmall, MonthStyleItem.self)
        self.capture("month-allTogglesOff", canvas: WidgetCanvas.small) {
            WidgetVariant.monthSmall.previewView(look)
        }
    }

    @MainActor
    func test_weekEventsView_allTogglesOff() {
        let look = self.allOffLook(.twoWeekEvents, WeekEventsStyleItem.self)
        self.capture("weekEvents-allTogglesOff", canvas: WidgetCanvas.medium) {
            WidgetVariant.twoWeekEvents.previewView(look)
        }
    }

    @MainActor
    func test_todayAndNextView_timeZoneOff() {
        let look = self.allOffLook(.todayAndNextMedium, TodayAndNextStyleItem.self)
        let sample = TodayAndNextWidgetViewModel.sample()
        // 샘플엔 타임존 문자열이 없고 날짜가 실행일이다 — 고정값을 넣어야 OFF 가 드러나고 png 가 안 밀린다.
        let fixedToday = TodayAndNextWidgetViewModel.TodayModel(
            weekOfDay: "Friday", day: 12, timeZonetext: "KST"
        )
        let leftRows: [any TodayAndNextWidgetViewModelRow] = [fixedToday] + Array(sample.left.rows.dropFirst())
        let model = sample
            |> \.left.rows .~ leftRows
            |> \.look .~ look
        self.capture("todayAndNext-timeZoneOff", canvas: WidgetCanvas.medium) {
            TodayAndNextWidgetView(model: model) { _, color in
                AnyView(WidgetPreviewTodoToggle(look: look, size: 16, customColor: color))
            }
        }
    }

    @MainActor
    func test_foremostView_typeLabelOff() {
        let look = self.allOffLook(.foremostSmall, ForemostStyleItem.self)
        self.capture("foremost-typeLabelOff", canvas: WidgetCanvas.small) {
            WidgetVariant.foremostSmall.previewView(look)
        }
    }

    @MainActor
    func test_aiCommandView_explainOff() {
        let look = self.allOffLook(.aiCommandSmall, AICommandStyleItem.self)
        self.capture("aiCommand-explainOff", canvas: WidgetCanvas.small) {
            WidgetVariant.aiCommandSmall.previewView(look)
        }
    }
}
