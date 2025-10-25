//
//  ForemostEventWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/19/24.
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


// MARK: - ForemostEventView

struct InlineSizeForemostEventView: View {
    
    private let model: ForemostEventWidgetViewModel
    init(model: ForemostEventWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        if let event = self.model.eventModel {
            Text(event.name)
                .widgetAccentable()
        } else {
            Text("widget.events.foremost::allFinished::message".localized())
                .widgetAccentable()
        }
    }
}

struct SystemSizeForemostEventView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private struct Metric {
        let emptyMessageFontSize: CGFloat
        let eventNameFontSize: CGFloat
        let eventNameNumberOfLines: Int
        let tagLineWidth: CGFloat
        let timeInfoFontSize: CGFloat
        init(_ isSmallSize: Bool) {
            self.emptyMessageFontSize = isSmallSize ? 16 : 20
            self.eventNameFontSize = isSmallSize ? 18 : 40
            self.eventNameNumberOfLines = isSmallSize ? 2 : 1
            self.tagLineWidth = isSmallSize ? 4 : 6
            self.timeInfoFontSize = isSmallSize ? 12 : 14
        }
    }
    
    private let model: ForemostEventWidgetViewModel
    private let isSmallSize: Bool
    private let metric: Metric
    init(model: ForemostEventWidgetViewModel, isSmallSize: Bool) {
        self.model = model
        self.isSmallSize = isSmallSize
        self.metric = .init(isSmallSize)
    }
    
    var body: some View {
        if let event = model.eventModel {
            eventView(event)
                .invalidatableContent()
        } else {
            emptyForemostEventView()
        }
    }
    
    private func eventTypeView() -> some View {
        Text("calendar::foremostevent:title".localized())
            .font(.system(size: 12))
            .foregroundStyle(colorSet.text2.asColor)
    }
    
    private func emptyForemostEventView() -> some View {
        VStack(alignment: .leading) {
            
            eventTypeView()
            
            Spacer(minLength: 12)
            
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 8) {
                    
                    Text(String.randomEmoji)
                 
                    Text("widget.events.foremost::allFinished::message".localized())
                        .font(.system(size: metric.emptyMessageFontSize, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(colorSet.text1.asColor)
                }
                Spacer()
            }
            
            Spacer(minLength: 8)
        }
    }
    
    private func eventView(_ event: any EventCellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            eventTypeView()
            
            VStack(alignment: .leading, spacing: 8) {
                eventTimeView(event.periodText, isTodo: event is TodoEventCellViewModel)
                
                nameAndActionView(event)
                
                if let todo = event as? TodoEventCellViewModel {
                    ForemostTodoToggleButton(todo: todo, colorSet: colorSet)
                } else {
                    Spacer().frame(height: 4)
                }
            }
        }
    }
    

    private func nameAndActionView(_ event: any EventCellViewModel) -> some View {
        HStack {
            
            Spacer().frame(width: metric.tagLineWidth+8)
            
            Text(event.name)
                .lineLimit(metric.eventNameNumberOfLines)
                .minimumScaleFactor(0.7)
                .font(.system(size: metric.eventNameFontSize, weight: .semibold))
                .foregroundStyle(colorSet.text0.asColor)
            
            Spacer()
        }
        .background(
            HStack(alignment: .center) {
                tagLineView()
                Spacer()
            }
        )
    }
    
    private func eventTimeView(_ periodText: EventPeriodText?, isTodo: Bool) -> some View {
        
        func singleText(_ text: EventTimeText) -> some View {
            return HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(text.singleLineAttrText(fontSize: metric.timeInfoFontSize))
                    .lineLimit(1)
                    .font(.system(size: metric.timeInfoFontSize))
                    .minimumScaleFactor(0.4)
                    .foregroundColor(colorSet.text1.asColor)
            }
        }
        
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            let seperator = isTodo ? "-" : "~"
            let topText = top.singleLineAttrText(fontSize: metric.timeInfoFontSize)
            let bottomText = bottom.singleLineAttrText(fontSize: metric.timeInfoFontSize)
            return Text("\(topText)\(seperator)\(bottomText)")
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .font(.system(size: metric.timeInfoFontSize))
                .foregroundColor(colorSet.text1.asColor)
        }
        
        switch periodText {
        case .singleText(let text): return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText): return doubleText(topText, bottomText).asAnyView()
        default: return EmptyView().asAnyView()
        }
    }
    
    private func tagLineView() -> some View {
        let defColors = EventTagColorSet(model.defaultTagColorSetting)
        let color = switch model.eventModel?.tagId {
        case .holiday: defColors.holiday
        case .default: defColors.defaultColor
        case .custom: model.tag?.colorHex.flatMap { UIColor.from(hex: $0) } ?? defColors.defaultColor
        default: defColors.defaultColor
        }
        
        let width = metric.tagLineWidth
        
        return RoundedRectangle(cornerRadius: width / 2)
            .fill(color.asColor)
            .frame(width: width)
            .padding(.vertical, 6)
    }
    
    struct ForemostTodoToggleButton: View {
        let todo: TodoEventCellViewModel
        let colorSet: ColorSet
        
        struct TodoToggleStyle: ToggleStyle {
            let colorSet: ColorSet
            func makeBody(configuration: Configuration) -> some View {
                HStack {
                    Spacer()
                    Text(configuration.isOn ? "common.cancel".localized() : "common.done".localized())
                        .font(.callout)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorSet.accent.asColor)
                        .opacity(configuration.isOn ? 0.8 : 1.0)
                )
            }
        }
        
        var body: some View {
            Toggle(
                "", isOn: false,
                intent: TodoToggleIntent(id: todo.eventIdentifier, isForemost: true)
            )
            .toggleStyle(TodoToggleStyle(colorSet: colorSet))
        }
    }
}


// MARK: - ForemostEventWidgetView

struct ForemostEventWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family: WidgetFamily
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let entry: ResultTimelineEntry<ForemostEventWidgetViewModel>
    init(entry: ResultTimelineEntry<ForemostEventWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model) where family == .accessoryInline:
            InlineSizeForemostEventView(model: model)
        case .success(let model) where family == .systemSmall:
            SystemSizeForemostEventView(model: model, isSmallSize: true)
        case .success(let model):
            SystemSizeForemostEventView(model: model, isSmallSize: false)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}

// MARK: - ForemostEventWidget

struct ForemostEventWidget: Widget {
    
    nonisolated static let kind: String = "ForemostEventWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ForemostEventWidget.kind, provider: ForemostEventWidgetTimelineProvider()) { entry in
            ForemostEventWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.accessoryInline, .systemSmall, .systemMedium])
        .configurationDisplayName("widget.events.foremost".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - preview

struct ForemostEventWidget_PreviewProvider: PreviewProvider {
    
    static var previews: some View {
        
        let sample = ForemostEventWidgetViewModel.sample()
//            |> \.eventModel .~ nil
        
        let entry = ResultTimelineEntry(date: Date(), result: .success(sample))

        Group {
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .containerBackground(.background, for: .widget)
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(.background, for: .widget)
        }
    }
}
