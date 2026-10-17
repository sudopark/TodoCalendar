//
//  ViewAppearance+GoogleCalendar.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Domain
import CommonPresentation


extension ViewAppearance {

    public convenience init(google colors: GoogleCalendar.Colors, _ tags: [String: GoogleCalendar.Tag]) {
        self.init(
            setting: .init(
                calendar: .init(colorSetKey: .systemTheme, fontSetKey: .systemDefault),
                defaultTagColor: .default),
            isSystemDarkTheme: false
        )
        let ownerIds = Set(tags.values.map { $0.ownerId })
        ownerIds.forEach { self.googleCalendarColors[$0] = colors }
        self.googleCalendarTagMap.merge(tags) { $1 }
    }
}
