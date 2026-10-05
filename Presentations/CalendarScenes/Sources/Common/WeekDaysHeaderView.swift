//
//  WeekDaysHeaderView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation
import CalendarPresentation


struct WeekDaysHeaderView: View {

    private let weekDays: [WeekDayModel]

    @Environment(ViewAppearance.self) private var appearance

    init(weekDays: [WeekDayModel]) {
        self.weekDays = weekDays
    }

    var body: some View {
        let grid: [GridItem] = Array(repeating: .init(.flexible(minimum: 30), spacing: 0), count: 7)
        let textColor: (WeekDayModel) -> Color = {
            let accent: AccentDays? = $0.isSunday ? .sunday : $0.isSaturday ? .saturday : nil
            return appearance.accentCalendarDayColor(accent).asColor
        }
        return LazyVGrid(columns: grid) {
            ForEach(self.weekDays, id: \.identifier) { weekDay in
                Text(weekDay.symbol)
                    .font(self.appearance.fontSet.weekday.asFont)
                    .foregroundColor(textColor(weekDay))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
