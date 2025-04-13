//
//  EventListWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
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
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let model: EventListWidgetViewModel
    init(model: EventListWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<model.pages.count, id: \.self) { pageIndex in
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<model.pages[pageIndex].sections.count, id: \.self) { index in
                        eventListPerDayView(model.pages[pageIndex].sections[index])
                    }
                    
                    if model.pages[pageIndex].needBottomSpace {
                        Spacer()
                    }
                }
            }
        }
        .invalidatableContent()
    }
    
    private func eventListPerDayView(
        _ model: EventListWidgetViewModel.SectionModel
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 2.5) {
            if let title = model.sectionTitle {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        model.shouldAccentTitle
                        ? colorSet.text0.asColor : colorSet.text2.asColor
                    )
            }
            
            if model.events.isEmpty {
                Text("widget.events.noEvents::message".localized())
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .font(.system(size: 13))
                    .foregroundStyle(colorSet.text1.asColor)
                    
            } else {
                ForEach(0..<model.events.count, id: \.self) { index in
                    eventView(model.events[index])
                        .frame(height: 25)
                }
            }
        }
    }
    
    private func eventView(_ model: any EventCellViewModel) -> some View {
        HStack(spacing: 2) {
            
            timeTextView(model.periodText)
                .frame(width: 30)
            
            tagLineView(model.tagId)
            
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
                    .foregroundColor(colorSet.text1.asColor)
            }
        }
        
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(top.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.text1.asColor)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                 
                    Text(bottom.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.text1.asColor)
                }
            }
        }
        
        switch periodText {
        case .singleText(let text): return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText): return doubleText(topText, bottomText).asAnyView()
        default: return EmptyView().asAnyView()
        }
    }
    
    private func tagLineView(_ tagId: EventTagId?) -> some View {
        let defColors = EventTagColorSet(model.defaultTagColorSetting)
        let color = switch tagId {
        case .holiday: defColors.holiday
        case .default: defColors.defaultColor
        case .custom(let id): self.model.customTagMap[id].flatMap { UIColor.from(hex: $0.colorHex) } ?? defColors.defaultColor
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
                .foregroundStyle(colorSet.text0.asColor)
            
            Spacer()
            
            if let todo = model as? TodoEventCellViewModel {
                TodoToggleButton(todo: todo, colorSet: colorSet)
            }
        }
    }
}

private struct TodoToggleButton: View {
    let todo: TodoEventCellViewModel
    let colorSet: ColorSet
    
    struct TodoToggleStyle: ToggleStyle {
        
        let colorSet: ColorSet
        
        func makeBody(configuration: Configuration) -> some View {
            Image(systemName: configuration.isOn ? "circle.inset.filled" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(colorSet.accent.asColor)
        }
    }
    
    var body: some View {
        Toggle(
            "", isOn: false,
            intent: TodoToggleIntent(id: todo.eventIdentifier, isForemost: false)
        )
        .toggleStyle(TodoToggleStyle(colorSet: colorSet))
    }
}

// MARK: - EventListWidgetView

struct EventListWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
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
    
    nonisolated static let kind: String = "EventList"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: Self.kind,
            intent: EventListTypeSelectIntent.self,
            provider: EventListWidgetTimeLineProvider()
        ) { entry in
            EventListWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("widget.events::name".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct EventListWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        
        let size: WidgetFamily = .systemMedium
        let sample = EventListWidgetViewModel.sample(size: .init(size))
        let entry = ResultTimelineEntry(date: Date(), result: .success(sample))
        
        return EventListWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: size))
            .containerBackground(.background, for: .widget)
    }
}
