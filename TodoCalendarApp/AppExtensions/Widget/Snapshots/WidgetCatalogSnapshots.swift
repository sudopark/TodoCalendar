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
import Extensions
import SnapshotTestHelpKit
import WidgetScenes
import CalendarPresentation

@testable import TodoCalendarAppWidget
import CalendarDomainInterface
import CalendarDomainTesting
import EventDomainInterface
import EventDomainTesting
import SettingDomainInterface
import SettingDomainTesting


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
        self.capture(
            name, family: family, canvas: canvas,
            plateView: { Rectangle().fill(.background) },
            testName: testName, makeView: makeView
        )
    }

    @MainActor
    private func capture<P: View, V: View>(
        _ name: String,
        family: WidgetFamily,
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
            snapshotDirectory: catalogSnapshotDirectory(),
            testName: testName
        ) { _ in
            ZStack {
                plateView()
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
            let model = TodayAndNextWidgetViewModel.sample()
            return TodayAndNextWidgetView(model: model) { _, color in
                AnyView(
                    Toggle("", isOn: .constant(false))
                        .toggleStyle(
                            TodoToggleStyle(
                                colorSet: model.look.background.colorSet(true),
                                size: 16, customColor: color
                            )
                        )
                )
            }
        }
    }

    @MainActor
    func test_widgetTodayAndNextStyled() {
        let background = WidgetAppearanceSettings.Background.custom(hex: "#101820")
        let style = WidgetStyle(
            id: .init(variant: .todayAndNextMedium, style: .custom(id: "night")),
            name: nil,
            setting: TodayAndNextStyleSetting.initial,
            background: background
        )
        let model = TodayAndNextWidgetViewModel.sample()
            |> \.look .~ WidgetLook(globalSetting: .init(), appliedStyle: style)
        self.capture(
            "widget-today-and-next-styled",
            family: .systemMedium,
            canvas: WidgetCanvas.medium,
            plateView: { Rectangle().fill(WidgetBackgroundStyle(background).shape) }
        ) {
            TodayAndNextWidgetView(model: model) { _, color in
                AnyView(
                    Toggle("", isOn: .constant(false))
                        .toggleStyle(
                            TodoToggleStyle(
                                colorSet: model.look.background.colorSet(true),
                                size: 16, customColor: color
                            )
                        )
                )
            }
        }
    }

    @MainActor
    func test_widgetDDayPhoto() {
        let target = Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 26, hour: 7)
        ) ?? Date()
        let targetTime = EventTime.at(target.timeIntervalSince1970)
        let style = WidgetStyle(
            id: .init(variant: .ddayMedium, style: .custom(id: "photo")),
            name: nil,
            setting: DDayStyleSetting.initial,
            photo: self.bokehPhoto()
        )
        let model = DDayWidgetViewModel(
            eventTitle: "catalog.event::anniversary".catalogLocalized(),
            ddayText: DDayText(14).text,
            dateText: targetTime.ddayDateText(in: .current),
            timeText: targetTime.ddayTimeText(in: .current),
            repeatText: ""
        )
        |> \.look .~ WidgetLook(globalSetting: .init(), appliedStyle: style)
        self.capture(
            "widget-dday-photo",
            family: .systemMedium,
            canvas: WidgetCanvas.medium,
            plateView: {
                WidgetBackgroundView(
                    look: model.look,
                    in: RoundedRectangle(cornerRadius: WidgetCanvas.cornerRadius, style: .continuous)
                )
            }
        ) {
            DDayMediumWidgetView(model: model)
        }
    }

    @MainActor
    private func bokehPhoto() -> WidgetStylePhoto {
        let renderer = ImageRenderer(content: BokehPhotoFixtureView())
        renderer.scale = BokehPhotoFixture.renderScale
        let url = FileManager.default.temporaryDirectory
            .appending(path: "widget-catalog-photo-\(UUID().uuidString).png")
        try? renderer.uiImage?.pngData()?.write(to: url, options: .atomic)
        return .init(id: nil, original: url, rendering: url)
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
    func test_widgetEventAndForemost() {
        self.capture("widget-event-and-foremost", family: .systemMedium, canvas: WidgetCanvas.medium) {
            let model = EventAndForemostWidgetViewModel(
                event: .sample(size: .medium), foremost: .sample()
            )
            return EventAndForemostWidgetView(
                entry: ResultTimelineEntry(date: Date(), result: .success(model))
            )
        }
    }

    @MainActor
    func test_widgetEventAndMonth() {
        self.capture("widget-event-and-month", family: .systemMedium, canvas: WidgetCanvas.medium) {
            let model = EventAndMonthWidgetViewModel(
                event: .sample(size: .medium), month: try! MonthWidgetViewModel.makeSample()
            )
            return EventAndMonthWidgetView(
                entry: ResultTimelineEntry(date: Date(), result: .success(model))
            )
        }
    }

    @MainActor
    func test_widgetDoubleMonth() {
        self.capture("widget-double-month", family: .systemMedium, canvas: WidgetCanvas.medium) {
            let model = DoubleMonthWidgetViewModel(
                current: try! MonthWidgetViewModel.makeSample(),
                next: try! MonthWidgetViewModel.makeSampleNextMonth()
            )
            return DoubleMonthWidgetContentView(model: model)
        }
    }

    @MainActor
    func test_widgetTodayAndMonth() {
        self.capture("widget-today-and-month", family: .systemMedium, canvas: WidgetCanvas.medium) {
            let model = TodayAndMonthWidgetViewModel(
                today: .sample(), month: try! MonthWidgetViewModel.makeSample()
            )
            return TodayAndMonthWidgetContentView(model: model)
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
    func test_widgetDDay() {
        self.capture("widget-dday", family: .systemSmall, canvas: WidgetCanvas.small) {
            DDaySmallWidgetView(model: .sample)
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
                placeName: "catalog.place::meeting_room".catalogLocalized()
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
            AICommandShortcutWidgetView(look: .init(globalSetting: .init()))
        }
    }
}


// MARK: - 마케팅 소재

extension WidgetCatalogSnapshots {

    private var marketingPhotoPath: String {
        let filePath = "\(#filePath)"
        guard let range = filePath.range(of: "/TodoCalendarApp/") else { return filePath }
        return "\(filePath[..<range.lowerBound])/snapshot-fixtures/marketing/dday-photo.jpg"
    }

    @MainActor
    func test_marketingDDayPhoto() throws {
        let path = self.marketingPhotoPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("마케팅 사진 원본이 없다 — gitignore 자리라 클론마다 넣어야 한다 (\(path))")
        }
        let url = URL(fileURLWithPath: path)
        let target = Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 26, hour: 7)
        ) ?? Date()
        let targetTime = EventTime.at(target.timeIntervalSince1970)
        let style = WidgetStyle(
            id: .init(variant: .ddayMedium, style: .custom(id: "photo")),
            name: nil,
            setting: DDayStyleSetting.initial,
            photo: .init(id: nil, original: url, rendering: url)
        )
        let model = DDayWidgetViewModel(
            eventTitle: "catalog.event::anniversary".catalogLocalized(),
            ddayText: DDayText(14).text,
            dateText: targetTime.ddayDateText(in: .current),
            timeText: targetTime.ddayTimeText(in: .current),
            repeatText: ""
        )
        |> \.look .~ WidgetLook(globalSetting: .init(), appliedStyle: style)
        self.capture(
            "marketing-dday-photo",
            family: .systemMedium,
            canvas: WidgetCanvas.medium,
            plateView: {
                WidgetBackgroundView(
                    look: model.look,
                    in: RoundedRectangle(cornerRadius: WidgetCanvas.cornerRadius, style: .continuous)
                )
            }
        ) {
            DDayMediumWidgetView(model: model)
        }
    }

    @MainActor
    func test_marketingTodayPink() {
        let background = WidgetAppearanceSettings.Background.custom(hex: "#FBD3E0")
        let style = WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .custom(id: "pink")),
            name: nil,
            setting: TodayStyleSetting.initial,
            background: background
        )
        let model = TodayWidgetViewModel.sample()
            |> \.look .~ WidgetLook(globalSetting: .init(), appliedStyle: style)
        self.capture(
            "marketing-today-pink",
            family: .systemSmall,
            canvas: WidgetCanvas.small,
            plateView: { Rectangle().fill(WidgetBackgroundStyle(background).shape) }
        ) {
            TodayWidgetView(entry: ResultTimelineEntry(date: Date(), result: .success(model)))
        }
    }

    @MainActor
    func test_marketingForemostSky() {
        let background = WidgetAppearanceSettings.Background.custom(hex: "#D6E4FF")
        let style = WidgetStyle(
            id: .init(variant: .foremostSmall, style: .custom(id: "sky")),
            name: nil,
            setting: ForemostStyleSetting.initial,
            background: background
        )
        let model = ForemostEventWidgetViewModel.sample()
            |> \.look .~ WidgetLook(globalSetting: .init(), appliedStyle: style)
        self.capture(
            "marketing-foremost-sky",
            family: .systemSmall,
            canvas: WidgetCanvas.small,
            plateView: { Rectangle().fill(WidgetBackgroundStyle(background).shape) }
        ) {
            ForemostEventWidgetView(entry: ResultTimelineEntry(date: Date(), result: .success(model)))
        }
    }
}


// MARK: - 마케팅 영상 장면

extension WidgetCatalogSnapshots {

    private enum DynamicIslandCanvas {
        static let size = CGSize(width: 400, height: 190)
        static let island = CGSize(width: 371, height: 160)
        static let cornerRadius: CGFloat = 44
    }

    private func makeMarketingDeadlineActivityModel() -> EventCountdownActivityViewModel {
        let eventDate = Date().addingTimeInterval(1 * 3600 + 58 * 60 + 23)
        let displayTime = Calendar.current.date(
            bySettingHour: 11, minute: 40, second: 0, of: Date()
        ) ?? eventDate
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let attributes = EventCountdownActivityAttributes(target: .todo(id: "plan-deadline"))
        let state = EventCountdownActivityAttributes.State(
            eventName: "catalog.event::plan_deadline".catalogLocalized(),
            eventTimeText: timeFormatter.string(from: displayTime),
            tagColorHex: "#2F6FED",
            eventDate: eventDate,
            startDate: eventDate.addingTimeInterval(-3 * 3600)
        )
        return EventCountdownActivityViewModel(attributes, state)
    }

    @MainActor
    private func makeMarketingTodoCheckView(isChecked: Bool) -> some View {
        let report = TodoEventCellViewModel(
            currentTodo: TodoCalendarEvent(
                current: TodoEvent(uuid: "report-draft", name: "catalog.todo::send_report_draft".catalogLocalized()),
                isForemost: false
            )
        )
        var model = TodayAndNextWidgetViewModel.sample()
        let todayRows = model.left.rows.filter { $0 is TodayAndNextWidgetViewModel.TodayModel }
        let otherRows = model.left.rows.filter { row in
            guard let event = row as? TodayAndNextWidgetViewModel.EventModel else { return false }
            return !(event.cvm is TodoEventCellViewModel)
        }
        model.left = .init(rows: todayRows + [TodayAndNextWidgetViewModel.EventModel(cvm: report)] + otherRows)
        return TodayAndNextWidgetView(model: model) { cvm, color in
            AnyView(
                Toggle("", isOn: .constant(isChecked && cvm.eventIdentifier == report.eventIdentifier))
                    .toggleStyle(
                        TodoToggleStyle(
                            colorSet: model.look.background.colorSet(true),
                            size: 16, customColor: color
                        )
                    )
            )
        }
    }

    @MainActor
    func test_marketingTodoCheck() {
        self.capture("marketing-todo-check-before", family: .systemMedium, canvas: WidgetCanvas.medium) {
            self.makeMarketingTodoCheckView(isChecked: false)
        }
        self.capture("marketing-todo-check-after", family: .systemMedium, canvas: WidgetCanvas.medium) {
            self.makeMarketingTodoCheckView(isChecked: true)
        }
    }

    @MainActor
    func test_marketingLockScreenLiveActivity() {
        self.captureLockScreen("marketing-lockscreen-live-activity", canvas: LockScreenCanvas.liveActivity) {
            EventCountdownLockScreenView(model: self.makeMarketingDeadlineActivityModel(), isStale: false)
        }
    }

    /// 아일랜드는 ActivityConfiguration 안에서만 그려져 스냅샷이 못 잡는다 — 펼친 영역 배치를 검은 알약 위에 같은 조각 뷰로 다시 세운다.
    @MainActor
    func test_marketingDynamicIsland() {
        let model = self.makeMarketingDeadlineActivityModel()
        self.captureLockScreen("marketing-dynamic-island", canvas: DynamicIslandCanvas.size) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    EventCountdownSymbolBadge(diameter: 26)
                        .padding(.leading, 6)
                    Spacer()
                    EventCountdownTimerText(
                        model: model, isStale: false,
                        liveFont: .system(size: 22, weight: .semibold),
                        staleFont: .system(size: 14)
                    )
                    .padding(.trailing, 6)
                }
                Spacer(minLength: 0)
                EventCountdownTitleBlock(model: model)
                EventCountdownProgressBar(model: model)
                EventCountdownActionButtonRow(model: model)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: DynamicIslandCanvas.island.width, height: DynamicIslandCanvas.island.height)
            .background(
                RoundedRectangle(cornerRadius: DynamicIslandCanvas.cornerRadius, style: .continuous)
                    .fill(Color.black)
            )
            .foregroundStyle(.white)
        }
    }
}


// MARK: - 디데이 위젯 배경 사진 픽스처

private struct BokehLight {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let color: Int
    let alpha: Double
}

// 좌표는 미디엄 위젯의 2배(pt) 공간 기준이고 renderScale 로 되돌린다
private enum BokehPhotoFixture {
    static let canvas = CGSize(width: 2184, height: 1020)
    static let renderScale: CGFloat = 0.5
    static let blurRadius: CGFloat = 10
    static let backgroundColors: [Color] = [
        Color(red: 20 / 255, green: 24 / 255, blue: 58 / 255),
        Color(red: 70 / 255, green: 36 / 255, blue: 80 / 255)
    ]
    static let lightColors: [Color] = [
        Color(red: 255 / 255, green: 206 / 255, blue: 120 / 255),
        Color(red: 255 / 255, green: 170 / 255, blue: 90 / 255),
        Color(red: 255 / 255, green: 236 / 255, blue: 180 / 255),
        Color(red: 255 / 255, green: 140 / 255, blue: 160 / 255)
    ]
    static let lights: [BokehLight] = [
        .init(x: 617, y: 404, radius: 61, color: 0, alpha: 69),
        .init(x: 385, y: 374, radius: 88, color: 0, alpha: 124),
        .init(x: 153, y: 88, radius: 47, color: 3, alpha: 113),
        .init(x: 985, y: 92, radius: 28, color: 3, alpha: 67),
        .init(x: 914, y: 645, radius: 35, color: 0, alpha: 133),
        .init(x: 203, y: 999, radius: 70, color: 1, alpha: 65),
        .init(x: 1186, y: 429, radius: 37, color: 1, alpha: 129),
        .init(x: 1263, y: 573, radius: 35, color: 1, alpha: 73),
        .init(x: 1525, y: 99, radius: 44, color: 0, alpha: 132),
        .init(x: 843, y: 508, radius: 27, color: 3, alpha: 100),
        .init(x: 1856, y: 370, radius: 79, color: 2, alpha: 91),
        .init(x: 999, y: 83, radius: 43, color: 2, alpha: 127),
        .init(x: 1406, y: 746, radius: 83, color: 3, alpha: 96),
        .init(x: 483, y: 524, radius: 29, color: 3, alpha: 81),
        .init(x: 622, y: 955, radius: 63, color: 3, alpha: 113),
        .init(x: 317, y: 782, radius: 25, color: 2, alpha: 103),
        .init(x: 2034, y: 593, radius: 64, color: 3, alpha: 68),
        .init(x: 1105, y: 485, radius: 31, color: 0, alpha: 67),
        .init(x: 1825, y: 291, radius: 59, color: 3, alpha: 104),
        .init(x: 1891, y: 363, radius: 22, color: 1, alpha: 138),
        .init(x: 2022, y: 60, radius: 34, color: 1, alpha: 96),
        .init(x: 1014, y: 407, radius: 36, color: 3, alpha: 123),
        .init(x: 681, y: 459, radius: 30, color: 3, alpha: 130),
        .init(x: 560, y: 838, radius: 55, color: 3, alpha: 130),
        .init(x: 1701, y: 1010, radius: 55, color: 2, alpha: 108),
        .init(x: 618, y: 84, radius: 49, color: 1, alpha: 79),
        .init(x: 955, y: 12, radius: 49, color: 3, alpha: 135),
        .init(x: 1076, y: 288, radius: 43, color: 0, alpha: 78),
        .init(x: 1512, y: 624, radius: 73, color: 2, alpha: 76),
        .init(x: 221, y: 467, radius: 85, color: 3, alpha: 110),
        .init(x: 1614, y: 106, radius: 71, color: 3, alpha: 111),
        .init(x: 780, y: 68, radius: 27, color: 1, alpha: 116),
        .init(x: 450, y: 348, radius: 40, color: 0, alpha: 73),
        .init(x: 619, y: 549, radius: 20, color: 0, alpha: 106),
        .init(x: 288, y: 895, radius: 23, color: 1, alpha: 138),
        .init(x: 608, y: 649, radius: 68, color: 2, alpha: 104),
        .init(x: 1942, y: 125, radius: 66, color: 0, alpha: 122),
        .init(x: 1967, y: 495, radius: 79, color: 2, alpha: 70),
        .init(x: 418, y: 767, radius: 38, color: 2, alpha: 93),
        .init(x: 661, y: 528, radius: 81, color: 0, alpha: 86),
        .init(x: 1481, y: 150, radius: 87, color: 0, alpha: 127),
        .init(x: 372, y: 712, radius: 58, color: 2, alpha: 126),
        .init(x: 684, y: 364, radius: 66, color: 1, alpha: 128),
        .init(x: 2059, y: 337, radius: 89, color: 1, alpha: 138),
        .init(x: 980, y: 837, radius: 44, color: 3, alpha: 89),
        .init(x: 2120, y: 504, radius: 45, color: 2, alpha: 63),
        .init(x: 1144, y: 483, radius: 23, color: 2, alpha: 84),
        .init(x: 1831, y: 827, radius: 64, color: 2, alpha: 106),
        .init(x: 903, y: 104, radius: 30, color: 1, alpha: 120),
        .init(x: 1383, y: 209, radius: 45, color: 3, alpha: 139),
        .init(x: 1963, y: 931, radius: 20, color: 2, alpha: 70),
        .init(x: 1591, y: 801, radius: 35, color: 1, alpha: 121),
        .init(x: 1777, y: 808, radius: 42, color: 2, alpha: 71),
        .init(x: 1897, y: 411, radius: 70, color: 0, alpha: 80),
        .init(x: 520, y: 28, radius: 41, color: 1, alpha: 135),
        .init(x: 598, y: 626, radius: 79, color: 3, alpha: 104),
        .init(x: 536, y: 21, radius: 39, color: 0, alpha: 73),
        .init(x: 570, y: 444, radius: 87, color: 1, alpha: 87),
        .init(x: 1031, y: 217, radius: 23, color: 2, alpha: 124),
        .init(x: 1335, y: 265, radius: 50, color: 3, alpha: 76)
    ]
}

private struct BokehPhotoFixtureView: View {

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: BokehPhotoFixture.backgroundColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            ZStack(alignment: .topLeading) {
                ForEach(BokehPhotoFixture.lights.indices, id: \.self) { index in
                    let light = BokehPhotoFixture.lights[index]
                    Circle()
                        .fill(BokehPhotoFixture.lightColors[light.color].opacity(light.alpha / 255))
                        .frame(width: light.radius * 2, height: light.radius * 2)
                        .offset(x: light.x - light.radius, y: light.y - light.radius)
                }
            }
            .frame(
                width: BokehPhotoFixture.canvas.width,
                height: BokehPhotoFixture.canvas.height,
                alignment: .topLeading
            )
            .blur(radius: BokehPhotoFixture.blurRadius)
        }
        .frame(width: BokehPhotoFixture.canvas.width, height: BokehPhotoFixture.canvas.height)
        .clipped()
    }
}
