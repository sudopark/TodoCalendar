//
//  NextEventWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - NextEventWidgetView

struct NextEventWidgetView: View {
    
    private let model: NextEventWidgetViewModel
    init(model: NextEventWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        VStack {
            Text(
                model.timeText.map { "\($0) - \(model.eventTitle)" } ?? model.eventTitle
            )
        }
    }
}


struct NextEventWidgetEntryView: View {
    private let entry: ResultTimelineEntry<NextEventWidgetViewModel>
    init(entry: ResultTimelineEntry<NextEventWidgetViewModel>) {
        self.entry = entry
    }
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            NextEventWidgetView(model: model)
        case .failure:
            VStack{ }
        }
    }
}


struct NextEventWidget: Widget {
    
    nonisolated static  let kind: String = "NextEventWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextEventWidgetTimeLineProvider()) { entry in
            NextEventWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.accessoryInline])
        .configurationDisplayName("widget.next.title".localized())
        .description("widget.common::explain".localized())
    }
}


struct NextEventWidgetView_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = NextEventWidgetViewModel.sample
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
//        let entry: ResultTimelineEntry<NextEventWidgetViewModel> = ResultTimelineEntry(date: Date(), result: .failure(.init(error: RuntimeError("ss"))))
        
        return NextEventWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .containerBackground(.background, for: .widget)
    }
}
