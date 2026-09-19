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
    func previewView(_ look: WidgetLook) -> AnyView {
        switch self {
        case .todayAndNextMedium: return self.todayAndNextPreview(look)
        case .eventListSmall: return self.eventListPreview(look, size: .small)
        case .eventListMedium: return self.eventListPreview(look, size: .medium)
        case .eventListLarge: return self.eventListPreview(look, size: .large)
        case .monthSmall: return self.monthPreview(look)
        case .todaySummarySmall: return self.todaySummaryPreview(look)
        case .foremostInline: return self.foremostInlinePreview(look)
        case .foremostSmall: return self.foremostSystemPreview(look, isSmallSize: true)
        case .foremostMedium: return self.foremostSystemPreview(look, isSmallSize: false)
        case .ddaySmall:
            return AnyView(DDaySmallWidgetView(model: self.ddaySample(look)))
        case .ddayMedium:
            return AnyView(DDayMediumWidgetView(model: self.ddaySample(look)))
        case .ddayCircular:
            return AnyView(DDayCircularWidgetView(model: self.ddaySample(look)))
        case .ddayRectangular:
            return AnyView(DDayRectangularWidgetView(model: self.ddaySample(look)))
        case .ddayInline:
            return AnyView(DDayInlineWidgetView(model: self.ddaySample(look)))
        case .oneWeekEvents: return self.weekEventsPreview(look, range: .weeks(count: 1))
        case .twoWeekEvents: return self.weekEventsPreview(look, range: .weeks(count: 2))
        case .threeWeekEvents: return self.weekEventsPreview(look, range: .weeks(count: 3))
        case .fourWeekEvents: return self.weekEventsPreview(look, range: .weeks(count: 4))
        case .currentMonthEvents:
            return self.weekEventsPreview(look, range: .wholeMonth(.current))
        case .lastMonthEvents:
            return self.weekEventsPreview(look, range: .wholeMonth(.previous))
        case .nextMonthEvents:
            return self.weekEventsPreview(look, range: .wholeMonth(.next))
        case .aiCommandCircular: return AnyView(AICommandCircularView())
        case .aiCommandSmall: return AnyView(AICommandSmallView(look: look))
        case .nextEventInline:
            return AnyView(NextEventWidgetInlineView(model: .sample))
        case .nextEventRectangular:
            return AnyView(NextEventRectangleWidgetView(model: .sample))
        case .nextRemainRectangular:
            return AnyView(NextRemainEventVListiew(model: .sample))
        case .doubleMonthMedium: return self.doubleMonthPreview(look)
        case .eventAndMonthMedium: return self.eventAndMonthPreview(look)
        case .eventAndForemostMedium: return self.eventAndForemostPreview(look)
        case .todayAndMonthMedium: return self.todayAndMonthPreview(look)
        }
    }
}


// MARK: - single widget previews

extension WidgetVariant {

    @MainActor
    private func todayAndNextPreview(_ look: WidgetLook) -> AnyView {
        let model = TodayAndNextWidgetViewModel.sample() |> \.look .~ look
        return AnyView(
            TodayAndNextWidgetView(model: model) { _, color in
                AnyView(WidgetPreviewTodoToggle(look: look, size: 16, customColor: color))
            }
        )
    }

    @MainActor
    private func eventListPreview(
        _ look: WidgetLook, size: EventListWidgetSize
    ) -> AnyView {
        let model = EventListWidgetViewModel.sample(size: size) |> \.look .~ look
        return AnyView(
            EventListView(model: model) { _ in
                AnyView(WidgetPreviewTodoToggle(look: look))
            }
        )
    }

    @MainActor
    private func monthPreview(_ look: WidgetLook) -> AnyView {
        guard let model = try? MonthWidgetViewModel.makeSample()
        else { return AnyView(EmptyView()) }
        return AnyView(SingleMonthView(model: model |> \.look .~ look))
    }

    @MainActor
    private func todaySummaryPreview(_ look: WidgetLook) -> AnyView {
        let model = TodayWidgetViewModel.sample() |> \.look .~ look
        return AnyView(TodaySummaryView(model: model))
    }

    @MainActor
    private func foremostInlinePreview(_ look: WidgetLook) -> AnyView {
        let model = ForemostEventWidgetViewModel.sample() |> \.look .~ look
        return AnyView(InlineSizeForemostEventView(model: model))
    }

    @MainActor
    private func foremostSystemPreview(
        _ look: WidgetLook, isSmallSize: Bool
    ) -> AnyView {
        let model = ForemostEventWidgetViewModel.sample() |> \.look .~ look
        return AnyView(
            SystemSizeForemostEventView(model: model, isSmallSize: isSmallSize) { _ in
                AnyView(WidgetPreviewForemostTodoToggle(look: look))
            }
        )
    }

    private func ddaySample(_ look: WidgetLook) -> DDayWidgetViewModel {
        return DDayWidgetViewModel.sample |> \.look .~ look
    }

    @MainActor
    private func weekEventsPreview(
        _ look: WidgetLook, range: WeekEventsRange
    ) -> AnyView {
        let model = WeekEventsViewModel.sample(range) |> \.look .~ look
        return AnyView(WeekEventsView(model: model))
    }
}


// MARK: - composed widget previews

extension WidgetVariant {

    @MainActor
    private func doubleMonthPreview(_ look: WidgetLook) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().doubleMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            DoubleMonthWidgetContentView(
                model: model.applying(look)
            )
        )
    }

    @MainActor
    private func eventAndMonthPreview(_ look: WidgetLook) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().eventAndMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            EventAndMonthWidgetContentView(
                model: model.applying(look)
            ) { _ in
                AnyView(WidgetPreviewTodoToggle(look: look))
            }
        )
    }

    @MainActor
    private func eventAndForemostPreview(_ look: WidgetLook) -> AnyView {
        let model = ComposedWidgetSampleFactory().eventAndForemost().applying(look)
        return AnyView(
            EventAndForemostWidgetContentView(
                model: model,
                todoToggle: { _ in
                    AnyView(WidgetPreviewTodoToggle(look: look))
                },
                foremostTodoToggle: { _ in
                    AnyView(WidgetPreviewForemostTodoToggle(look: look))
                }
            )
        )
    }

    @MainActor
    private func todayAndMonthPreview(_ look: WidgetLook) -> AnyView {
        guard let model = ComposedWidgetSampleFactory().todayAndMonth()
        else { return AnyView(EmptyView()) }
        return AnyView(
            TodayAndMonthWidgetContentView(
                model: model.applying(look)
            )
        )
    }
}


// MARK: - preview toggles

struct WidgetPreviewTodoToggle: View {

    @Environment(\.colorScheme) private var colorScheme

    private let look: WidgetLook
    private let size: CGFloat
    private let customColor: Color?

    init(look: WidgetLook, size: CGFloat = 18, customColor: Color? = nil) {
        self.look = look
        self.size = size
        self.customColor = customColor
    }

    var body: some View {
        Toggle("", isOn: .constant(false))
            .toggleStyle(
                TodoToggleStyle(
                    colorSet: look.background.colorSet(colorScheme == .light),
                    size: size,
                    customColor: customColor
                )
            )
    }
}


struct WidgetPreviewForemostTodoToggle: View {

    @Environment(\.colorScheme) private var colorScheme

    private let look: WidgetLook

    init(look: WidgetLook) {
        self.look = look
    }

    var body: some View {
        Toggle("", isOn: .constant(false))
            .toggleStyle(
                ForemostTodoToggleStyle(
                    colorSet: look.background.colorSet(colorScheme == .light)
                )
            )
    }
}
