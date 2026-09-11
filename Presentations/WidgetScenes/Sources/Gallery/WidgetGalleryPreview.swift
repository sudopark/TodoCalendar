//
//  WidgetGalleryPreview.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


// MARK: - canvas layout

extension WidgetPreviewCanvas {

    var size: CGSize {
        switch self {
        case .systemSmall: return .init(width: 170, height: 170)
        case .systemMedium: return .init(width: 364, height: 170)
        case .systemLarge: return .init(width: 364, height: 382)
        case .accessoryInline: return .init(width: 240, height: 26)
        case .accessoryRectangular: return .init(width: 160, height: 72)
        case .accessoryCircular: return .init(width: 72, height: 72)
        }
    }

    var contentMargin: CGFloat {
        return self.isLockScreen ? 0 : 16
    }

    var cornerRadius: CGFloat {
        return self.isLockScreen ? 0 : 22
    }

    var previewPlateInset: CGFloat {
        return self.isLockScreen ? Metric.Spacing.small : 0
    }

    func previewPlateShape(_ scale: CGFloat) -> RoundedRectangle {
        switch self {
        case .accessoryCircular:
            // 판은 캔버스에 여백까지 더한 크기라 반지름도 그 크기로 잡아야 정원이 된다.
            let plateWidth = self.size.width * scale + self.previewPlateInset * 2
            return .init(cornerRadius: plateWidth / 2, style: .circular)
        case .accessoryInline, .accessoryRectangular:
            return .init(cornerRadius: Metric.Radius.large, style: .continuous)
        case .systemSmall, .systemMedium, .systemLarge:
            return .init(cornerRadius: self.cornerRadius * scale, style: .continuous)
        }
    }

    var previewAspect: CGFloat {
        return self.size.width / self.size.height
    }

    func previewScale(fitting box: CGSize) -> CGFloat {
        let plate = self.previewPlateInset * 2
        let width = max(box.width - plate, 1)
        let height = box.height.isFinite ? max(box.height - plate, 1) : box.height
        return min(width / self.size.width, height / self.size.height, 1)
    }
}


// MARK: - variant preview

extension WidgetVariant {

    @MainActor
    func previewView(_ setting: WidgetAppearanceSettings) -> AnyView {
        switch self {
        case .todayAndNextMedium: return self.todayAndNextPreview(setting)
        case .eventListSmall: return self.eventListPreview(setting, size: .small)
        case .eventListMedium: return self.eventListPreview(setting, size: .medium)
        case .eventListLarge: return self.eventListPreview(setting, size: .large)
        case .monthSmall: return self.monthPreview(setting)
        case .todaySummarySmall: return self.todaySummaryPreview(setting)
        case .foremostInline: return self.foremostInlinePreview(setting)
        case .foremostSmall: return self.foremostSystemPreview(setting, isSmallSize: true)
        case .foremostMedium: return self.foremostSystemPreview(setting, isSmallSize: false)
        case .ddaySmall:
            return AnyView(DDaySmallWidgetView(model: self.ddaySample(setting)))
        case .ddayMedium:
            return AnyView(DDayMediumWidgetView(model: self.ddaySample(setting)))
        case .ddayCircular:
            return AnyView(DDayCircularWidgetView(model: self.ddaySample(setting)))
        case .ddayRectangular:
            return AnyView(DDayRectangularWidgetView(model: self.ddaySample(setting)))
        case .ddayInline:
            return AnyView(DDayInlineWidgetView(model: self.ddaySample(setting)))
        case .oneWeekEvents: return self.weekEventsPreview(setting, range: .weeks(count: 1))
        case .twoWeekEvents: return self.weekEventsPreview(setting, range: .weeks(count: 2))
        case .threeWeekEvents: return self.weekEventsPreview(setting, range: .weeks(count: 3))
        case .fourWeekEvents: return self.weekEventsPreview(setting, range: .weeks(count: 4))
        case .currentMonthEvents:
            return self.weekEventsPreview(setting, range: .wholeMonth(.current))
        case .lastMonthEvents:
            return self.weekEventsPreview(setting, range: .wholeMonth(.previous))
        case .nextMonthEvents:
            return self.weekEventsPreview(setting, range: .wholeMonth(.next))
        case .aiCommandCircular: return AnyView(AICommandCircularView())
        case .aiCommandSmall: return AnyView(AICommandSmallView(setting: setting))
        case .nextEventInline:
            return AnyView(NextEventWidgetInlineView(model: .sample))
        case .nextEventRectangular:
            return AnyView(NextEventRectangleWidgetView(model: .sample))
        case .nextRemainRectangular:
            return AnyView(NextRemainEventVListiew(model: .sample))
        case .doubleMonthMedium: return self.doubleMonthPreview(setting)
        case .eventAndMonthMedium: return self.eventAndMonthPreview(setting)
        case .eventAndForemostMedium: return self.eventAndForemostPreview(setting)
        case .todayAndMonthMedium: return self.todayAndMonthPreview(setting)
        }
    }
}


// MARK: - single widget previews

extension WidgetVariant {

    @MainActor
    private func todayAndNextPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        let model = TodayAndNextWidgetViewModel.sample() |> \.widgetSetting .~ setting
        return AnyView(
            TodayAndNextWidgetView(model: model) { _, color in
                AnyView(
                    WidgetPreviewTodoToggle(setting: setting, size: 16, customColor: color)
                )
            }
        )
    }

    @MainActor
    private func eventListPreview(
        _ setting: WidgetAppearanceSettings, size: EventListWidgetSize
    ) -> AnyView {
        let model = EventListWidgetViewModel.sample(size: size) |> \.widgetSetting .~ setting
        return AnyView(
            EventListView(model: model) { _ in
                AnyView(WidgetPreviewTodoToggle(setting: setting))
            }
        )
    }

    @MainActor
    private func monthPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        guard let model = try? MonthWidgetViewModel.makeSample()
        else { return AnyView(EmptyView()) }
        return AnyView(SingleMonthView(model: model |> \.widgetSetting .~ setting))
    }

    @MainActor
    private func todaySummaryPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        let model = TodayWidgetViewModel.sample() |> \.widgetSetting .~ setting
        return AnyView(TodaySummaryView(model: model))
    }

    @MainActor
    private func foremostInlinePreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        let model = ForemostEventWidgetViewModel.sample() |> \.widgetSetting .~ setting
        return AnyView(InlineSizeForemostEventView(model: model))
    }

    @MainActor
    private func foremostSystemPreview(
        _ setting: WidgetAppearanceSettings, isSmallSize: Bool
    ) -> AnyView {
        let model = ForemostEventWidgetViewModel.sample() |> \.widgetSetting .~ setting
        return AnyView(
            SystemSizeForemostEventView(model: model, isSmallSize: isSmallSize) { _ in
                AnyView(WidgetPreviewForemostTodoToggle(setting: setting))
            }
        )
    }

    private func ddaySample(_ setting: WidgetAppearanceSettings) -> DDayWidgetViewModel {
        return DDayWidgetViewModel.sample |> \.widgetSetting .~ setting
    }

    @MainActor
    private func weekEventsPreview(
        _ setting: WidgetAppearanceSettings, range: WeekEventsRange
    ) -> AnyView {
        let model = WeekEventsViewModel.sample(range) |> \.widgetSetting .~ setting
        return AnyView(WeekEventsView(model: model))
    }
}


// MARK: - composed widget previews

extension WidgetVariant {

    @MainActor
    private func doubleMonthPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().doubleMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            DoubleMonthWidgetContentView(
                model: model
                |> \.current.widgetSetting .~ setting
                |> \.next.widgetSetting .~ setting
            )
        )
    }

    @MainActor
    private func eventAndMonthPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().eventAndMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            EventAndMonthWidgetContentView(
                model: model
                |> \.event.widgetSetting .~ setting
                |> \.month.widgetSetting .~ setting
            ) { _ in
                AnyView(WidgetPreviewTodoToggle(setting: setting))
            }
        )
    }

    @MainActor
    private func eventAndForemostPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        let model = ComposedWidgetSampleFactory().eventAndForemost()
        |> \.event.widgetSetting .~ setting
        |> \.foremost.widgetSetting .~ setting
        return AnyView(
            EventAndForemostWidgetContentView(
                model: model,
                todoToggle: { _ in
                    AnyView(WidgetPreviewTodoToggle(setting: setting))
                },
                foremostTodoToggle: { _ in
                    AnyView(WidgetPreviewForemostTodoToggle(setting: setting))
                }
            )
        )
    }

    @MainActor
    private func todayAndMonthPreview(_ setting: WidgetAppearanceSettings) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().todayAndMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            TodayAndMonthWidgetContentView(
                model: model
                |> \.today.widgetSetting .~ setting
                |> \.month.widgetSetting .~ setting
            )
        )
    }
}


// MARK: - preview toggles

struct WidgetPreviewTodoToggle: View {

    @Environment(\.colorScheme) private var colorScheme

    private let setting: WidgetAppearanceSettings
    private let size: CGFloat
    private let customColor: Color?

    init(setting: WidgetAppearanceSettings, size: CGFloat = 18, customColor: Color? = nil) {
        self.setting = setting
        self.size = size
        self.customColor = customColor
    }

    var body: some View {
        Toggle("", isOn: .constant(false))
            .toggleStyle(
                TodoToggleStyle(
                    colorSet: setting.background.colorSet(colorScheme == .light),
                    size: size,
                    customColor: customColor
                )
            )
    }
}


struct WidgetPreviewForemostTodoToggle: View {

    @Environment(\.colorScheme) private var colorScheme

    private let setting: WidgetAppearanceSettings

    init(setting: WidgetAppearanceSettings) {
        self.setting = setting
    }

    var body: some View {
        Toggle("", isOn: .constant(false))
            .toggleStyle(
                ForemostTodoToggleStyle(
                    colorSet: setting.background.colorSet(colorScheme == .light)
                )
            )
    }
}
