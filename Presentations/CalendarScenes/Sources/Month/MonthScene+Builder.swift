//
//  MonthScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//

import Foundation
import Domain
import Scenes


// MARK: CurrentSelectedDay and Event components

struct CurrentSelectDayModel: Equatable {
    
    let year: Int
    let month: Int
    let day: Int
    let weekId: String
    let range: Range<TimeInterval>
    var holiday: Holiday?
    
    var identifier: String { "\(year)-\(month)-\(day)" }
    
    init(
        _ year: Int, _ month: Int, _ day: Int,
        weekId: String, range: Range<TimeInterval>
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.weekId = weekId
        self.range = range
    }
}

// MARK: - MonthScene

protocol MonthSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

protocol MonthSceneListener: AnyObject {
    
    func monthScene(
        didChange currentSelectedDay: CurrentSelectDayModel,
        and eventsThatDay: [any CalendarEvent]
    )
}

protocol MonthScene: Scene where Interactor == any MonthSceneInteractor {
}

struct MonthSceneComponent {
    let viewModel: any MonthViewModel
}

protocol MonthSceneBuilder: AnyObject {
    
    func makeSceneComponent(_ month: CalendarMonth) -> MonthSceneComponent
}
