//
//  NextEventWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/5/25.
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


// MARK: - NextEventWidgetView

struct NextEventWidgetInlineView: View {
    
    private let model: NextEventWidgetViewModel
    init(model: NextEventWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        VStack {
            Text(
                model.timeText.map { "\($0.singleLineText) - \(model.eventTitle)" } ?? model.eventTitle
            )
        }
    }
}

struct NextEventRectangleWidgetView: View {
    
    private let model: NextEventWidgetViewModel
    init(model: NextEventWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                Image("small_icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                
                Text("widget.next.rect_widget::title".localized())
                    .font(.footnote)
            }
            .foregroundStyle(.primary)
            .opacity(0.8)
            
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    if let time = model.timeText {
                        Text(time.singleLineAttrText())
                    }
                    if let location = model.locationText {
                        Text(location)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                HStack {
                    Text(model.eventTitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
            }
            .padding(.leading, 4)
        }
    }
}

struct NextEventWidgetEntryView: View {
    
    private let entry: ResultTimelineEntry<NextEventWidgetViewModel>
    
    @Environment(\.widgetFamily) var family: WidgetFamily
    
    init(entry: ResultTimelineEntry<NextEventWidgetViewModel>) {
        self.entry = entry
    }
    var body: some View {
        switch self.entry.result {
        case .success(let model) where family == .accessoryInline:
            NextEventWidgetInlineView(model: model)
                .widgetURL(model.eventLink)
            
        case .success(let model):
            NextEventRectangleWidgetView(model: model)
                .widgetURL(model.eventLink)
            
        case .failure(let error) where family == .accessoryRectangular:
            FailView(errorModel: error)
            
        case .failure:
            VStack{ }
        }
    }
}


struct NextEventWidget: Widget {
    
    nonisolated static let kind: String = "NextEventWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextEventWidgetTimeLineProvider()) { entry in
            NextEventWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
        .configurationDisplayName("widget.next.title".localized())
        .description("widget.common::explain".localized())
    }
}


struct NextEventWidgetView_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = NextEventWidgetViewModel.sample
            |> \.locationText .~ "회의실"
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        
        return Group {
            NextEventWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .containerBackground(.background, for: .widget)
            
            NextEventWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .containerBackground(.background, for: .widget)
        }
    }
}
