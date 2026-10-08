//
//  ContinuousMonthsScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import CalendarPresentation


// MARK: - ContinuousMonthsScene

protocol ContinuousMonthsSceneInteractor: AnyObject {

    func changeFocusedMonth(to month: CalendarMonth)
    func selectDay(_ day: CalendarDay)
}

typealias SelectDayAndEvents = (CurrentSelectDayModel, [any CalendarEvent])

protocol ContinuousMonthsSceneListener: AnyObject {

    func continuousMonths(didScrollTo month: CalendarMonth)
    func continuousMonths(didSelect day: CalendarDay)
    func continuousMonths(didRequestShare range: Range<TimeInterval>, kind: CalendarShareRangeKind)
    func continuousMonths(didChangeSelectedDay day: SelectDayAndEvents, and nextDays: [SelectDayAndEvents])
}

struct ContinuousMonthSection: Equatable {
    let month: CalendarMonth
    let weeks: [WeekRowModel]
}
