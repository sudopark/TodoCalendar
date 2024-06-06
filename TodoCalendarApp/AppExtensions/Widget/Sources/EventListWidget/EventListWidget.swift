//
//  EventListWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - EventListView

struct EventListView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultLightColorSet()
    }
    
    @State private var pendingDoneTodoIds: Set<String> = []
    
    private let model: EventListWidgetViewModel
    init(model: EventListWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<model.lists.count, id: \.self) { index in
                eventListPerDayView(model.lists[index])
            }
        }
    }
    
    private func eventListPerDayView(
        _ model: EventListWidgetViewModel.DayEventListModel
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 2.5) {
            Text(model.dateText)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    model.isStartDate
                    ? colorSet.normalText.asColor : colorSet.subSubNormalText.asColor
                )
            
            ForEach(0..<model.events.count, id: \.self) { index in
                eventView(model.events[index])
                    .frame(height: 25)
            }
        }
    }
    
    private func eventView(_ model: any EventCellViewModel) -> some View {
        HStack(spacing: 2) {
            
            timeTextView(model.periodText)
                .frame(width: 30)
            
            tagLineView(model.tagColor)
            
            nameAndActionView(model)
            
        }
    }
    
    private func timeTextView(_ periodText: EventPeriodText?) -> some View {
        
        func singleText(_ text: EventTimeText) -> some View {
            return HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(text.text)
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .minimumScaleFactor(0.7)
                    .foregroundColor(colorSet.subNormalText.asColor)
            }
        }
        
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(top.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.subNormalText.asColor)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                 
                    Text(bottom.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.subNormalText.asColor)
                }
            }
        }
        
        switch periodText {
        case .singleText(let text): return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText): return doubleText(topText, bottomText).asAnyView()
        default: return EmptyView().asAnyView()
        }
    }
    
    private func tagLineView(_ tagColor: EventTagColor?) -> some View {
        let defColors = EventTagColorSet(model.defaultTagColorSetting)
        let color = switch tagColor {
        case .holiday: defColors.holiday
        case .default: defColors.defaultColor
        case .custom(let hex): UIColor.from(hex: hex) ?? defColors.defaultColor
        default: defColors.defaultColor
        }
        
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(color.asColor)
            .frame(width: 3)
            .padding(.vertical, 2)
    }
    
    private func nameAndActionView(_ model: any EventCellViewModel) -> some View {
        return HStack {
            Text(model.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.system(size: 13))
                .foregroundColor(colorSet.normalText.asColor)
            
            Spacer()
            
            // TODO: 일단은 임시로 구현
            if let todo = model as? TodoEventCellViewModel {
                TodoToggleButton(id: todo.eventIdentifier, colorSet: colorSet)
            }
        }
    }
}

struct DummyTodoIntent: AppIntent {
    
    static var title: LocalizedStringResource = "test"
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

private struct TodoToggleButton: View {
    let id: String
    let colorSet: ColorSet
    
    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Toggle(isOn: false, intent: DummyTodoIntent()) {
                Image(systemName: "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(colorSet.accent.asColor)
            }
            .buttonStyle(PlainButtonStyle())
            .asAnyView()
        } else {
            EmptyView().asAnyView()
        }
    }
}

// MARK: - EventListWidgetView

struct EventListWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultLightColorSet()
    }
    
    private let entry: ResultTimelineEntry<EventListWidgetViewModel>
    init(entry: ResultTimelineEntry<EventListWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            EventListView(model: model)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - EventListWidget

struct EventListWidget: Widget {
    
    let kind: String = "EventList"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventListWidgetTimeLineProvider()) { entry in
            if #available(iOS 17.0, *) {
                EventListWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                EventListWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("TODO: My Widget")
        .description("TODO: This is an example widget.")
    }
}


// MARK: - preview

struct EventListWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        
        let lunchEvent = ScheduleEventCellViewModel("lunch", name: "🍔 \("Lunch".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .singleText(.init(text: "1:00"))
        
        let callTodoEvent = TodoEventCellViewModel("call", name: "📞 \("Call Sara".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .doubleText(
                .init(text: "01:00"),
                .init(text: "3:00")
            )
        
        let surfingEvent = ScheduleEventCellViewModel("surfing", name: "🏄‍♂️ \("Surfing".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .singleText(.init(text: "Allday".localized()))
        
        let june3 = EventListWidgetViewModel.DayEventListModel(
            dateText: "TUE, JUN 3",
            events: [ lunchEvent, callTodoEvent ],
            isStartDate: true
        )
        
        let july = EventListWidgetViewModel.DayEventListModel(dateText: "SUN, JUL 16", events: [
            surfingEvent
        ])

        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        
        let sample = EventListWidgetViewModel(
            lists: [june3, july],
            defaultTagColorSetting: defaultTagColorSetting
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(sample))
        
        if #available(iOS 17.0, *) {
            return EventListWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            return EventListWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
