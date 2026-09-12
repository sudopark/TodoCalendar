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
        static let widerDayFontSize: CGFloat = 50
        static let widestDayFontSize: CGFloat = 56
        static let monthFontSize: CGFloat = 13
        static let widerMonthFontSize: CGFloat = 15
        static let widestMonthFontSize: CGFloat = 17
    }
    
    private let model: TodayWidgetViewModel
    public init(model: TodayWidgetViewModel) {
        self.model = model
    }
    
    private var dayFontSize: CGFloat {
        switch model.eventCountLines {
        case .both: return Constant.dayFontSize
        case .one: return Constant.widerDayFontSize
        case .empty: return Constant.widestDayFontSize
        }
    }
    
    private var monthFontSize: CGFloat {
        switch model.eventCountLines {
        case .both: return Constant.monthFontSize
        case .one: return Constant.widerMonthFontSize
        case .empty: return Constant.widestMonthFontSize
        }
    }
    
    /// 개수 두 줄이 다 차면 월·년이 날짜에 붙고, 줄이 빌수록 하단 블록에 실려 아래로 내려앉는다.
    private var monthSitsUnderDay: Bool {
        return model.eventCountLines == .both
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                
                dayView(model)
                
                if monthSitsUnderDay {
                    monthAndYearView(model)
                }
                
                Spacer(minLength: 0)
                
                VStack(alignment: .leading, spacing: 2) {
                    if monthSitsUnderDay == false {
                        monthAndYearView(model)
                    }
                    
                    eventCountView(model)
                }
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
                
                if let holiday = model.displayHolidayName {
                    Text(holiday)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colorSet.holidayOrWeekEndWithAccent.asColor)
                }
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text("\(model.day)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(size: dayFontSize, weight: .semibold))
                    .foregroundStyle(colorSet.text0.asColor)
                
                if let timeZone = model.displayTimeZoneText {
                    Text(timeZone)
                        .font(.system(size: 10))
                        .foregroundStyle(colorSet.text1.asColor)
                }
            }
        }
    }
    
    private func monthAndYearView(_ model: TodayWidgetViewModel) -> some View {
        Text(model.monthAndYearText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.system(size: monthFontSize))
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
