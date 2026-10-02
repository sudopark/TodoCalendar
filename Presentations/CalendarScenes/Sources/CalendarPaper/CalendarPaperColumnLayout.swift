//
//  CalendarPaperColumnLayout.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


enum CalendarPaperColumnLayout: Equatable {
    case singleColumn
    case twoColumns

    init(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) {
        let isBothRegular = horizontal == .regular && vertical == .regular
        self = isBothRegular ? .twoColumns : .singleColumn
    }

    func showsCollapsedMonth(isCollapsed: Bool) -> Bool {
        return isCollapsed && self == .singleColumn
    }

    func forwardsDayTap(isReselect: Bool) -> Bool {
        return !(isReselect && self == .twoColumns)
    }
}


extension EnvironmentValues {
    @Entry var calendarPaperColumnLayout: CalendarPaperColumnLayout = .singleColumn
}
