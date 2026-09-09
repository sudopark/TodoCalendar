//
//  TodayWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions
import CommonPresentation
import CalendarPresentation


// MARK: - TodaySummaryView

public struct TodaySummaryView: View {
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private let model: TodayWidgetViewModel
    public init(model: TodayWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
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
