//
//  WeekEventsView.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - WeekEventsView

struct WeekEventsView: View {
    
    private enum Metric {
        static let eventRowHeightWithSpacing: CGFloat = 10
        static let eventTopMargin: CGFloat = 14
        static let eventInterspacing: CGFloat = 1
    }
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultLightColorSet()
    }
    
    private let model: WeekEventsViewModel
    
    init(
        model: WeekEventsViewModel
    ) {
        self.model = model
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            monthInfoView
            
            weekDaysHeaderView
            
            GeometryReader { proxy in
                gridWeeksView(proxy)
            }
        }
    }
    
    private var monthInfoView: some View {
        HStack {
            Text(model.targetMonthText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colorSet.text0.asColor)
            Spacer()
            if let label = model.range.monthLabel {
                Text(label)
                    .font(.system(size: 10))
                    .padding(3)
                    .foregroundStyle(colorSet.text1.asColor)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(colorSet.todayBackground.asColor)
                    )
            }
        }
    }
    
    private var weekDaysHeaderView: some View {
        let textColor: (WeekDayModel) -> UIColor = {
            return $0.isSunday || $0.isSaturday ? colorSet.weekEndText : colorSet.weekDayText
        }
        return HStack {
            ForEach(model.orderedWeekDaysModel, id: \.identifier) { day in
                Text(day.symbol)
                    .font(.system(size: 8))
                    .foregroundStyle(textColor(day).asColor)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func gridWeeksView(_ proxy: GeometryProxy) -> some View {
        let dayWidth = ceil(proxy.size.width/7)
        let dayHeight = ceil(proxy.size.height/CGFloat(model.weeks.count))
        let daySize = CGSize(width: dayWidth, height: dayHeight)
        return VStack(spacing: 0) {
            ForEach(model.weeks, id: \.id) { week in
                weekRowView(week, daySize)
            }
        }
    }
    
    private func weekRowView(_ week: WeekRowModel, _ daySize: CGSize) -> some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(week.days, id: \.identifier) {
                    dayView($0)
                        .frame(height: daySize.height)
                }
            }
            
            VStack(spacing: 0) {
                eventStackView(daySize, model.eventStackModelMap[week.id])
                Spacer()
            }
        }
    }
    
    private func dayView(_ day: DayCellViewModel) -> some View {
        
        let backgroundColor: Color = {
            if day.identifier == model.targetDayIndetifier {
                return self.colorSet.todayBackground.asColor
            } else {
                return .clear
            }
        }()
        let opacity: Double = {
            return day.identifier == model.targetDayIndetifier || day.isNotCurrentMonth == false
            ? 1.0 : 0.5
        }()
        
        return VStack(spacing: 0) {
            Text("\(day.day)")
                .font(.system(size: 9))
                .foregroundStyle(colorSet.textColor(accentDay: day.accentDay).asColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .opacity(opacity)
    }
    
    private func eventStackView(
        _ daySize: CGSize,
        _ stackModel: WeekEventStackViewModel?
    ) -> some View {
        let totalHeight = daySize.height - Metric.eventTopMargin
        let drawableRowCount = Int(totalHeight / Metric.eventRowHeightWithSpacing)
        let maxDrawableEventRowCount = drawableRowCount - 1
        guard maxDrawableEventRowCount > 0, let stackModel else { return EmptyView().asAnyView() }
        
        let size = min(maxDrawableEventRowCount, stackModel.linesStack.count)
        let moreEvents = stackModel.eventMores(with: size)
        
        return VStack(alignment: .leading, spacing: Metric.eventInterspacing) {
            ForEach(0..<size, id: \.self) {
                eventRowView(stackModel.linesStack[$0], daySize.width)
            }
            eventMoreViews(moreEvents, daySize.width)
        }
        .padding(.top, Metric.eventTopMargin)
        .asAnyView()
    }
    
    private func eventRowView(_ lines: [WeekEventLineModel], _ dayWidth: CGFloat) -> some View {
        return ZStack(alignment: .leading) {
            ForEach(0..<lines.count, id: \.self) {
                eventLineView(lines[$0], dayWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func eventLineView(_ line: WeekEventLineModel, _ dayWidth: CGFloat) -> some View {
        let offsetX = CGFloat(line.eventOnWeek.daysSequence.lowerBound-1) * dayWidth + Metric.eventInterspacing
        let width = CGFloat(line.eventOnWeek.daysSequence.count) * dayWidth - Metric.eventInterspacing
        let lineColor = colorSet.tagColor(line.lineColor, model.defaultTagColorSetting).asColor
        let background: some View = {
            if line.eventOnWeek.hasPeriod {
                return RoundedRectangle(cornerRadius: 2).fill(
                    lineColor.opacity(0.5)
                )
                .asAnyView()
            } else {
                return EmptyView().asAnyView()
            }
        }()
        return HStack(spacing: 2) {
             RoundedRectangle(cornerRadius: 12)
                 .fill(lineColor)
                 .frame(width: 2, height: 8)
                 .padding(.leading, 1)
             
             Text(line.eventOnWeek.name)
                .font(.system(size: 8))
                .minimumScaleFactor(0.5)
                .foregroundColor(colorSet.eventText.asColor)
                 .lineLimit(1)
        }
        .clipped()
         .frame(width: width, alignment: .leading)
         .background(background)
         .offset(x: offsetX)
    }
    
    private func eventMoreViews(_ moreModels: [EventMoreModel], _ dayWidth: CGFloat) -> some View {
        let offsetX: (EventMoreModel) -> CGFloat = { model in
            return CGFloat(model.daySequence-1) * dayWidth
        }
        return ZStack(alignment: .center) {
            ForEach(moreModels, id: \.daySequence) {
                Text("+\($0.moreCount)")
                    .font(.system(size: 8))
                    .foregroundColor(colorSet.eventText.asColor)
                    .frame(width: dayWidth)
                    .offset(x: offsetX($0))
            }
            .padding(.top, 2)
        }
    }
}


extension ColorSet {
    
    func textColor(accentDay: AccentDays?) -> UIColor {
        switch accentDay {
        case .holiday: return self.holidayText
        case .saturday, .sunday: return self.weekEndText
        default: return self.weekDayText
        }
    }
    
    func tagColor(_ tagColor: EventTagColor, _ defaultSetting: DefaultEventTagColorSetting) -> UIColor {
        switch tagColor {
        case .holiday: return UIColor.from(hex: defaultSetting.holiday) ?? .clear
        case .default: return UIColor.from(hex: defaultSetting.default) ?? .clear
        case .custom(let hex): return UIColor.from(hex: hex) ?? .clear
        }
    }
}

private extension WeekEventsRange {
    
    var monthLabel: String? {
        switch self {
        case .wholeMonth(let selection) where selection == .previous:
            return "Last month".localized()
        case .wholeMonth(let selection) where selection == .next:
            return "Next month".localized()
        default: return nil
        }
    }
}
