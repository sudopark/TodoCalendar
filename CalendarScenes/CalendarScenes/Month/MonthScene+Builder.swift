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

enum EventId: Equatable {
    case todo(String)
    case schedule(String, turn: Int)
    case holiday(_ holiday: Holiday)
}

struct CurrentSelectDayModel: Equatable {
    
    let year: Int
    let month: Int
    let day: Int
    let weekId: String
    let range: Range<TimeInterval>
    
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
        and eventsThatDay: [EventId]
    )
}

protocol MonthScene: Scene where Interactor == MonthSceneInteractor {
}

protocol MonthSceneBuilder: AnyObject {
    
    func makeMonthScene(_ month: CalendarMonth, listener: MonthSceneListener?) -> any MonthScene
}
