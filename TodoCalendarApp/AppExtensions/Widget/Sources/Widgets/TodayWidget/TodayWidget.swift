//
//  TodayWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/12/24.
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


// MARK: - TodaySummaryView

struct TodaySummaryView: View {
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private let model: TodayWidgetViewModel
    init(model: TodayWidgetViewModel) {
        self.model = model
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                
                dayView(model)
                
                Spacer()
                
                eventCountView(model)
            }
            Spacer(minLength: 0)
        }
        .asLinkIfPossible(model.id.link)
    }
    
    private func dayView(_ model: TodayWidgetViewModel) -> some View {
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading, spacing: -2) {
                Text(model.weekDayText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colorSet.text0.asColor)
                
                if let holiday = model.holidayName {
                    Text(holiday)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colorSet.holidayOrWeekEndWithAccent.asColor)
                }
            }
            
            VStack(alignment: .leading, spacing: -4) {
                
                HStack(alignment: .lastTextBaseline) {
                    Text("\(model.day)")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(colorSet.text0.asColor)
                        
                    VStack(alignment: .leading) {
                        
                        if let timeZone = model.timeZoneText {
                            Text(timeZone)
                                .font(.system(size: 10))
                                .foregroundStyle(colorSet.text1.asColor)
                        }
                        
                        Text(model.monthAndYearText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .font(.system(size: 13))
                            .foregroundStyle(colorSet.text1.asColor)
                    }
                }
            }
        }
    }
    
    private func eventCountView(_ model: TodayWidgetViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: -2) {
                Text(String(format: "total::event::count".localized(), model.totalEventCount))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colorSet.text0.asColor)
                HStack(spacing: 2) {
                    if model.todoEventCount > 0 {
                        Text(String(format: "todo::count".localized(), model.todoEventCount))
                            .font(.system(size: 10))
                            .foregroundStyle(colorSet.text2.asColor)
                    }
                    if model.scheduleEventcount > 0 {
                        Text(String(format: "schedule::count".localized(), model.scheduleEventcount))
                            .font(.system(size: 10))
                            .foregroundStyle(colorSet.text2.asColor)
                    }
                }
            }
        }
    }
}


// MARK: - TodayWidgetView

struct TodayWidgetView: View {
    
    private let entry: ResultTimelineEntry<TodayWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            TodaySummaryView(model: model)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - TodayWidget

struct TodayWidget: Widget {
    
    let kind: String = "TodaySummary"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("widget.events.today".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct TodayWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = TodayWidgetViewModel.sample()
//        |> \.timeZoneText .~ "GMT+9"
//        |> \.holidayName .~ "Christmas"
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return TodayWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .containerBackground(.background, for: .widget)
    }
}
