//
//  MonthWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 5/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import CommonPresentation
import CalendarScenes


struct MonthWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultLightColorSet()
    }
    
    private let entry: ResultTimelineEntry<MonthWidgetViewModel>
    init(entry: ResultTimelineEntry<MonthWidgetViewModel>) {
        self.entry = entry
    }
    
    private var model: MonthWidgetViewModel {
        return try! self.entry.result.get()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.monthName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorSet.normalText.asColor)
            
            Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 2) {
                GridRow {
                    ForEach(model.dayOfWeeksModels, id: \.identifier) { day in
                        dayOfWeekLabel(day)
                    }
                }
                ForEach(0..<model.weeks.count, id: \.self) { index in
                    GridRow {
                        ForEach(0..<model.weeks[index].days.count, id: \.self) { dayIndex in
                            dayTextLabel(model.weeks[index].days[dayIndex], today: model.todayIdentifier)
                        }
                    }
                }
            }
        }
    }
    
    private func dayOfWeekLabel(_ model: WeekDayModel) -> some View {
        let textColor: Color = {
            let accent: AccentDays? = model.isSunday ? .sunday : model.isSaturday ? .saturday : nil
            return self.accentDayText(accent)
        }()
        return Text(model.symbol)
            .font(.system(size: 10))
            .foregroundStyle(textColor)
    }
    
    private func dayTextLabel(_ model: DayCellViewModel, today: String) -> some View {
        let textColor: Color = {
            if model.identifier == today {
                return colorSet.selectedDayText.asColor
            } else {
                return self.accentDayText(model.accentDay)
            }
        }()
        let backgroundColor: Color = {
            if model.identifier == today {
                return colorSet.selectedDayBackground.asColor
            } else {
                return colorSet.dayBackground.asColor
            }
        }()
        let lineColor: Color = {
            if model.identifier == today {
                return colorSet.selectedDayText.asColor
            } else {
                return colorSet.weekDayText.asColor
            }
        }()
        return VStack(spacing: 2) {
            Text(model.isNotCurrentMonth ? "" : "\(model.day)")
                .font(.system(size: 10))
                .foregroundStyle(textColor)
            if !model.isNotCurrentMonth && self.model.hasEventDaysIdentifiers.contains(model.identifier) {
                Divider()
                    .background()
                    .background(lineColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(backgroundColor)
        )
    }
    
    private func accentDayText(_ accent: AccentDays?) -> Color {
        switch accent {
        case .holiday: return colorSet.holidayText.asColor
        case .sunday, .saturday: return colorSet.weekEndText.asColor
        default: return colorSet.weekDayText.asColor
        }
    }
}


// MARK: - MonthWidget

struct MonthWidget: Widget {
    
    let kind: String = "MonthWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: MonthWidgetTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                MonthWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MonthWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("TODO: My Widget")
        .description("TODO: This is an example widget.")
    }
}


// MARK: - preview

struct MonthWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let components = self.makeDummyComponent()
        let model = MonthWidgetViewModel(
            Date(),
            .sunday,
            TimeZone(abbreviation: "KST")!,
            components,
            "2024-9-4"
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        if #available(iOSApplicationExtension 17.0, *) {
            return MonthWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(for: .widget) {
                    
                }
        } else {
            return MonthWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
    
    private static func makeDummyComponent() -> CalendarComponent {
        let weekAndDays: [[(Int, Int)]] = [
            [(8, 27), (8, 28), (8, 29), (8, 30), (8, 31), (9, 1), (9, 2)],
            [(9, 3), (9, 4), (9, 5), (9, 6), (9, 7), (9, 8), (9, 9)],
            [(9, 10), (9, 11), (9, 12), (9, 13), (9, 14), (9, 15), (9, 16)],
            [(9, 17), (9, 18), (9, 19), (9, 20), (9, 21), (9, 22), (9, 23)],
            [(9, 24), (9, 25), (9, 26), (9, 27), (9, 28), (9, 29), (9, 30)]
        ]
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                return .init(year: 2024, month: pair.0, day: pair.1, weekDay: offset+1)
            }
            return CalendarComponent.Week(days: days)
        }
        return CalendarComponent(
            year: 2024, month: 9, weeks: weeks
        )
    }
}
