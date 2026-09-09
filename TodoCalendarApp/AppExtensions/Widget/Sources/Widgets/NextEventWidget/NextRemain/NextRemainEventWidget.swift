//
//  NextRemainEventWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/31/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation
import WidgetScenes


// MARK: - NextRemainEventWidgetView

struct NextRemainEventWidgetView: View {
    
    private let entry: ResultTimelineEntry<NextEventListWidgetViewModel>
    init(entry: ResultTimelineEntry<NextEventListWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            NextRemainEventVListiew(model: model)
            
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}

// MARK: - NextRemainEventWidget

struct NextRemainEventWidget: Widget {
    
    nonisolated static let kind: String = "NextRemainEventWidget"
 
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NextRemainEventWidgetTimeLineProvider()) { entry in
            
            NextRemainEventWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("widget.next.title::remains".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct NextRemainEventWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = NextEventListWidgetViewModel.sample
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        
        let emptyModel = NextEventListWidgetViewModel.empty
        let emptyEntry = ResultTimelineEntry(date: Date(), result: .success(emptyModel))
        
        return Group {
            NextRemainEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .containerBackground(.background, for: .widget)
            
            NextRemainEventWidgetView(entry: emptyEntry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .containerBackground(.background, for: .widget)
        }
    }
}
