//
//  TodayAndNextWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 12/21/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - widget view

struct TodayAndNextWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private let model: TodayAndNextWidgetViewModel
    private let defColors: EventTagColorSet
    init(model: TodayAndNextWidgetViewModel) {
        self.model = model
        self.defColors = .init(model.defaultTagColorSetting)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            self.pageView(model.left, isLeft: true)
                .frame(maxWidth: .infinity)
            self.pageView(model.right, isLeft: false)
                .frame(maxWidth: .infinity)
        }
        .invalidatableContent()
    }
    
    private func pageView(
        _ model: TodayAndNextWidgetViewModel.PageModel,
        isLeft: Bool
    ) -> some View {
        let isEmpty = isLeft ? model.rows.count == 1 : model.rows.isEmpty
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(model.rows, id: \.id) { model in
                Group {
                    switch model {
                    case let today as TodayAndNextWidgetViewModel.TodayModel:
                        todayView(today)
                    case let date as TodayAndNextWidgetViewModel.DateModel:
                        dateView(date)
                    case let event as TodayAndNextWidgetViewModel.EventModel:
                        eventView(event)
                    case let summary as TodayAndNextWidgetViewModel.MultipleEventsSummaryModel:
                        summaryView(summary)
                    case let uncompleted as TodayAndNextWidgetViewModel.UncompletedTodayTodoSummaryModel:
                        todayUncompletedTodoView(uncompleted)
                    default: EmptyView()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            
            if isEmpty {
                VStack {
                    Spacer()
                    Text(isLeft ? "widget.next.no_events_today".localized() : "widget.next.no_events".localized())
                        .font(.body)
                        .foregroundStyle(colorSet.text1.asColor)
                    Spacer()
                }
            }
        }
    }
    
    private func todayView(_ model: TodayAndNextWidgetViewModel.TodayModel) -> some View {
        HStack {
         
            VStack(alignment: .leading, spacing: -2) {
                Spacer()
                
                Text(model.weekOfDay)
                    .font(.system(size: 12))
                    .foregroundStyle(colorSet.text0.asColor)
                
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("\(model.day)")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(colorSet.text0.asColor)
                    
                    if let timeZonetext = model.timeZonetext {
                        Text("(\(timeZonetext))")
                            .font(.system(size: 8))
                            .foregroundStyle(colorSet.text0.asColor)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func dateView(_ model: TodayAndNextWidgetViewModel.DateModel) -> some View {
        HStack {
            Text(model.dateText)
                .font(.system(size: 12))
                .foregroundStyle(colorSet.text1.asColor)
            Spacer()
        }
    }
    
    private func eventView(_ model: TodayAndNextWidgetViewModel.EventModel) -> some View {
        let color = model.cvm.tagId.customTagId
            .flatMap { self.model.customTagMap[$0]?.colorHex }
            .flatMap { UIColor.from(hex: $0) }
        ?? defColors.defaultColor
        switch model.cvm {
        case let todo as TodoEventCellViewModel where todo.isAlldayEvent || todo.isCurrentTodo:
            return singleLineEventView(
                color: color, name: todo.name, todo: todo
            )
            .asLinkIfPossible(model.cvm.widgetURL)
            .asAnyView()
            
        case let todo as TodoEventCellViewModel:
            return doubleLineEventView(
                color: color, name: todo.name,
                time: todo.periodText?.asSingleLineText(isTodo: true),
                todo: todo
            )
            .asLinkIfPossible(model.cvm.widgetURL)
            .asAnyView()
            
        case let schedule as ScheduleEventCellViewModel where schedule.isAlldayEvent:
            return singleLineEventView(
                color: color, name: schedule.name
            )
            .asLinkIfPossible(model.cvm.widgetURL)
            .asAnyView()
            
        case let schedule as ScheduleEventCellViewModel:
            return doubleLineEventView(
                color: color,
                name: schedule.name,
                time: schedule.periodText?.asSingleLineText(isTodo: false)
            )
            .asLinkIfPossible(model.cvm.widgetURL)
            .asAnyView()
            
        case let holiday as HolidayEventCellViewModel:
            return singleLineEventView(
                color: defColors.holiday, name: holiday.name, isHoliday: true
            )
            .asLinkIfPossible(model.cvm.widgetURL)
            .asAnyView()
            
        case let google as GoogleCalendarEventCellViewModel:
            let appearance = ViewAppearance(
                google: self.model.googleCalendarColors,
                self.model.googleCalendarTags
            )
            let googleColor = appearance.googleEventColor(google.colorId, google.calendarId)
            
            if google.isAlldayEvent {
                return singleLineEventView(
                    color: googleColor, name: google.name
                )
                .asLinkIfPossible(model.cvm.widgetURL)
                .asAnyView()
            } else {
                return doubleLineEventView(
                    color: googleColor, name: google.name, time: google.periodText?.asSingleLineText(isTodo: false)
                )
                .asLinkIfPossible(model.cvm.widgetURL)
                .asAnyView()
            }
            
        default: return EmptyView().asAnyView()
        }
    }
    
    private func singleLineEventView(
        color: UIColor,
        name: String,
        isHoliday: Bool = false,
        todo: TodoEventCellViewModel? = nil
    ) -> some View {
        
        let invertColor: UIColor = switch (color.isLight, colorScheme == .light) {
        case (true, true): colorSet.text0
        case (true, false): colorSet.text0_inverted
        case (false, false): colorSet.text0
        case (false, true): colorSet.text0_inverted
        }
        
        return HStack(spacing: 4) {
            
            ZStack(alignment: .center) {
                Circle().fill(color.asColor)
                    .frame(width: 14, height: 14)
                
                Image(
                    systemName: isHoliday ? "star.fill" : todo == nil ? "calendar" : "flag.fill"
                )
                    .font(.system(size: 7))
                    .foregroundStyle(invertColor.asColor)
            }
            
            Text(name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.system(size: 12))
                .foregroundStyle(colorSet.text0.asColor)
            
            Spacer()
            
            if let todo {
                TodoToggleButton(
                    todo: todo, colorSet: colorSet, size: 12, customColor: color.asColor
                )
            }
        }
        .padding(.vertical, 0)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    color.withAlphaComponent(0.2).asColor
                )
        )
    }
    
    private func doubleLineEventView(
        color: UIColor,
        name: String,
        time: AttributedString? = nil,
        todo: TodoEventCellViewModel? = nil
    ) -> some View {
        HStack {
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.asColor)
                .padding(.vertical, 2)
                .frame(width: 3)
            
            VStack(alignment: .leading) {
                Text(name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.system(size: 12))
                    .foregroundStyle(colorSet.text0.asColor)
                
                if let time {
                    Text(time)
                        .lineLimit(1)
                        .font(.system(size: 10))
                        .minimumScaleFactor(0.4)
                        .foregroundStyle(colorSet.text1.asColor)
                }
            }
            
            Spacer()
            
            if let todo {
                TodoToggleButton(
                    todo: todo, colorSet: colorSet, size: 12, customColor: color.asColor
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    color.withAlphaComponent(0.2).asColor
                )
        )
    }
    
    private func summaryView(_ model: TodayAndNextWidgetViewModel.MultipleEventsSummaryModel) -> some View {
        var colors = model.tags.compactMap {
            $0.customTagId.flatMap { self.model.customTagMap[$0]?.colorHex }.flatMap { UIColor.from(hex: $0) } ?? defColors.defaultColor
        }
        .prefix(3)
        |> Set.init
        |> Array.init
        if colors.isEmpty {
            colors = [defColors.defaultColor]
        }
        let firstColor = colors.first ?? defColors.defaultColor
        
        let message = switch (model.todoCount == 0, model.nonTodoEventCount == 0) {
            case (true, true): ""
            case (true, false): "widget.next.title::more_events".localized(with: model.nonTodoEventCount)
            case (false, true): "widget.next.title::more_todos".localized(with: model.todoCount)
            case (false, false): "widget.next.title::more_events_with_todo".localized(with: model.todoCount, model.nonTodoEventCount)
        }
        
        return HStack {
            HStack(spacing: 2) {
                ForEach(colors, id: \.self) { c in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.asColor)
                        .padding(.vertical, 2)
                        .frame(width: 3)
                }
            }
            
            Text(message)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.system(size: 12))
                .foregroundStyle(colorSet.text0.asColor)
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    firstColor.withAlphaComponent(0.2).asColor
                )
        )
    }
    
    private func todayUncompletedTodoView(_ model: TodayAndNextWidgetViewModel.UncompletedTodayTodoSummaryModel) -> some View {
        
        let message = switch model.andOtherTodosCount {
            case 0: "widget.next.title::uncompleted::todo".localized(with: model.firstTodoName)
            default: "widget.next.title::uncompleted::todos".localized(with: model.firstTodoName, model.andOtherTodosCount)
        }
        let color = UIColor.red
        return HStack(spacing: 4) {
            
            ZStack(alignment: .center) {
                Circle().fill(color.asColor)
                    .frame(width: 14, height: 14)
                
                Image(
                    systemName: "exclamationmark.circle"
                )
                    .font(.system(size: 7))
                    .foregroundStyle(
                        colorSet.text0_inverted.asColor
                    )
            }
            
            Text(message)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.system(size: 12))
                .foregroundStyle(colorSet.text0.asColor)
            
            Spacer()
        }
        .padding(.vertical, 0)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    color.withAlphaComponent(0.2).asColor
                )
        )
    }
    
    private struct WeightedVLayout: Layout {
        var weights: [Float]
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            proposal.replacingUnspecifiedDimensions()
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let totalWeight = weights.reduce(0, +)
            var currentY = bounds.minY
            
            for (index, subview) in subviews.enumerated() {
                let weight = weights[index]
                let rowHeight = bounds.height * CGFloat(weight / totalWeight)
                
                subview.place(
                    at: CGPoint(x: bounds.minX, y: currentY),
                    proposal: ProposedViewSize(width: bounds.width, height: rowHeight)
                )
                currentY += rowHeight
            }
        }
    }
}


// MARK: - entry view

struct TodayAndNextWidgetEntryView: View {
    
    private let entry: ResultTimelineEntry<TodayAndNextWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayAndNextWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            TodayAndNextWidgetView(model: model)
            
        case .failure(let errorModel):
            FailView(errorModel: errorModel)
        }
    }
}


// MARK: - widget

struct TodayAndNextWidget: Widget {
    
    nonisolated static let kind: String = "TodayAndNextWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: EventListComponentSelectIntent.self,
            provider: TodayAndNextWidgetTimeLineProvider()
        ) { entry in
            
            TodayAndNextWidgetEntryView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.next.title::future".localized())
        .description("widget.common::explain".localized())
    }
}

private extension EventPeriodText {
    
    func asSingleLineText(isTodo: Bool) -> AttributedString {
        switch self {
        case .singleText(let txt):
            return txt.singleLineAttrText(fontSize: 10)
        case .doubleText(_, let bottom) where isTodo:
            return bottom.singleLineAttrText(fontSize: 10)
        case .doubleText(let top, let bottom):
            return top.singleLineAttrText(fontSize: 10) + " ~ " + bottom.singleLineAttrText(fontSize: 10)
        }
    }
}

// MARK: - preview

struct TodayAndNextWidgetView_Provider: PreviewProvider {
    
    static var previews: some View {
        
        var model = TodayAndNextWidgetViewModel.sample()
        var today = model.left.rows.first as? TodayAndNextWidgetViewModel.TodayModel
//        today?.holidays = ["삼일절"]
//        today?.timeZonetext = "UTC+9"
        model.left.rows[0] = today!
        
        // test uncompleted
        let uncompleted = TodayAndNextWidgetViewModel.UncompletedTodayTodoSummaryModel(
            [
                TodoCalendarEvent(TodoEvent(uuid: "t1", name: "todo1") |> \.eventTagId .~ .default, in: .current),
                TodoCalendarEvent(TodoEvent(uuid: "t2", name: "todo2") |> \.eventTagId .~ .default, in: .current)
            ]
        )
        model.left.rows.insert(uncompleted!, at: 1)
        
        // test holiday
        let holiday = HolidayEventCellViewModel(
            HolidayCalendarEvent(
                Holiday(uuid: "h", dateString: "2025-12-25", name: "크리스마스"),
                in: .current
            )!
        )
        model.left.rows.insert(TodayAndNextWidgetViewModel.EventModel(cvm: holiday), at: 2)
        
        // test multiple
//        var right = model.right
//        let multiple = TodayAndNextWidgetViewModel.MultipleEventsSummaryModel([
//            right.rows[2] as! TodayAndNextWidgetViewModel.EventModel,
//            right.rows[3] as! TodayAndNextWidgetViewModel.EventModel
//        ])
//        right.rows[right.rows.count-1] = multiple
//        model.right = right
        
        // test empty
//        model.left.rows = [model.left.rows.first!]
//        model.right.rows = []
        
        return TodayAndNextWidgetView(model: model)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
