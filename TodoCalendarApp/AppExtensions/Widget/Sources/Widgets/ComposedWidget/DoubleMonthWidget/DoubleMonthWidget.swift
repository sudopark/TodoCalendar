//
//  DoubleMonthWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - DoubleMonthWidgetView

struct DoubleMonthWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let entry: ResultTimelineEntry<DoubleMonthWidgetViewModel>
    init(entry: ResultTimelineEntry<DoubleMonthWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            HStack {
                SingleMonthView(model: model.current)
                SingleMonthView(model: model.next)
            }
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - DoubleMonthWidget

struct DoubleMonthWidget: Widget {
    
    let kind = "DoubleMonthWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoubleMonthWidgetTimlineProvider()) { entry in
            DoubleMonthWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.doubleMonth::name".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct DoubleMonthWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = DoubleMonthWidgetViewModel(
            current: try! MonthWidgetViewModel.makeSample(),
            next: try! MonthWidgetViewModel.makeSampleNextMonth()
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return DoubleMonthWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
