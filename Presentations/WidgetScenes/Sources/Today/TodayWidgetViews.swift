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
    
    private enum Constant {
        static let dayFontSize: CGFloat = 44
        static let expandedDayFontSize: CGFloat = 56
        static let monthFontSize: CGFloat = 13
        static let expandedMonthFontSize: CGFloat = 20
    }
    
    private let model: TodayWidgetViewModel
    public init(model: TodayWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                
                // 개수 블록이 통째로 비면 그만큼 빈 자리가 생긴다 — 날짜를 키워 세로 가운데로 옮긴다.
                if model.showsAnyEventCount {
                    dayView(model, dayFontSize: Constant.dayFontSize, inlinesMonthAndYear: true)
                    
                    Spacer()
                    
                    eventCountView(model)
                } else {
                    dayView(
                        model,
                        dayFontSize: Constant.expandedDayFontSize,
                        inlinesMonthAndYear: false
                    )
                    
                    Spacer()
                    
                    monthAndYearView(model, fontSize: Constant.expandedMonthFontSize)
                }
            }
            Spacer(minLength: 0)
        }
        .asLinkIfPossible(model.id.link)
    }
    
    private func dayView(
        _ model: TodayWidgetViewModel, dayFontSize: CGFloat, inlinesMonthAndYear: Bool
    ) -> some View {
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading, spacing: -2) {
                Text(model.weekDayText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colorSet.text0.asColor)
                
                if let holiday = model.displayHolidayName {
                    Text(holiday)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colorSet.holidayOrWeekEndWithAccent.asColor)
                }
            }
            
            VStack(alignment: .leading, spacing: -4) {
                
                HStack(alignment: .lastTextBaseline) {
                    Text("\(model.day)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(.system(size: dayFontSize, weight: .semibold))
                        .foregroundStyle(colorSet.text0.asColor)
                        
                    VStack(alignment: .leading) {
                        
                        if let timeZone = model.displayTimeZoneText {
                            Text(timeZone)
                                .font(.system(size: 10))
                                .foregroundStyle(colorSet.text1.asColor)
                        }
                        
                        if inlinesMonthAndYear {
                            monthAndYearView(model, fontSize: Constant.monthFontSize)
                        }
                    }
                }
            }
        }
    }
    
    private func monthAndYearView(
        _ model: TodayWidgetViewModel, fontSize: CGFloat
    ) -> some View {
        Text(model.monthAndYearText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.system(size: fontSize))
            .foregroundStyle(colorSet.text1.asColor)
    }
    
    private func eventCountView(_ model: TodayWidgetViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: -2) {
                if model.showsTotalCount {
                    Text(String(format: "total::event::count".localized(), model.totalEventCount))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorSet.text0.asColor)
                }
                HStack(spacing: 2) {
                    if model.showsTodoCount, model.todoEventCount > 0 {
                        Text(String(format: "todo::count".localized(), model.todoEventCount))
                            .font(.system(size: 10))
                            .foregroundStyle(colorSet.text2.asColor)
                    }
                    if model.showsScheduleCount, model.scheduleEventcount > 0 {
                        Text(String(format: "schedule::count".localized(), model.scheduleEventcount))
                            .font(.system(size: 10))
                            .foregroundStyle(colorSet.text2.asColor)
                    }
                }
            }
        }
    }
}
