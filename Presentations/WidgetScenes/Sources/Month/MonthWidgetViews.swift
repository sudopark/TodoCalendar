//
//  MonthWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


// MARK: - SingleMonthView

public struct SingleMonthView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private let model: MonthWidgetViewModel
    public init(model: MonthWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.monthName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorSet.text0.asColor)
            
            Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 2) {
                GridRow {
                    ForEach(model.dayOfWeeksModels, id: \.identifier) { day in
                        dayOfWeekLabel(day)
                    }
                }
                ForEach(0..<model.weeks.count, id: \.self) { index in
                    GridRow {
                        ForEach(0..<model.weeks[index].days.count, id: \.self) { dayIndex in
                            dayTextLabel(model.weeks[index].days[dayIndex], in: model)
                        }
                    }
                }
            }
        }
        .asLinkIfPossible(model.anchorDay.link)
    }
    
    private func dayOfWeekLabel(_ model: WeekDayModel) -> some View {
        let textColor: Color = {
            let accent: AccentDays? = model.isSunday ? .sunday : model.isSaturday ? .saturday : nil
            return self.accentDayText(accent)
        }()
        return Text(model.symbol)
            .font(.system(size: 10))
            .foregroundStyle(textColor)
    }
    
    private func dayTextLabel(
        _ model: DayCellViewModel, in monthModel: MonthWidgetViewModel
    ) -> some View {
        let textColor: Color = {
            if model.identifier == monthModel.todayIdentifier {
                return colorSet.selectedDayText.asColor
            } else {
                return self.accentDayText(model.accentDay)
            }
        }()
        let backgroundColor: Color = {
            if model.identifier == monthModel.todayIdentifier {
                return colorSet.selectedDayBackground.asColor
            } else {
                return colorSet.dayBackground.asColor
            }
        }()
        let lineColor: Color = {
            if model.identifier == monthModel.todayIdentifier {
                return colorSet.selectedDayText.asColor
            } else {
                return colorSet.weekDayText.asColor
            }
        }()
        return VStack(spacing: 2) {
            Text(model.isNotCurrentMonth ? "" : "\(model.day)")
                .font(.system(size: 10))
                .foregroundStyle(textColor)
            if !model.isNotCurrentMonth && monthModel.hasEventDaysIdentifiers.contains(model.identifier) {
                Divider()
                    .background()
                    .background(lineColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func accentDayText(_ accent: AccentDays?) -> Color {
        switch accent {
        case .holiday: return colorSet.holidayOrWeekEndWithAccent.asColor
        case .sunday, .saturday: return colorSet.weekEndText.asColor
        default: return colorSet.weekDayText.asColor
        }
    }
}
