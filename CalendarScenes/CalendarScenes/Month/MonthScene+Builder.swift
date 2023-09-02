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
    case holiday(_ dateString: String)
}

struct CurrentSelectDayModel: Equatable {
    let identifier: String
    let eventIds: [EventId]
    
    init(_ identifier: String, _ eventIds: [EventId]) {
        self.identifier = identifier
        self.eventIds = eventIds
    }
}

// MARK: - MonthScene

protocol MonthSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

protocol MonthSceneListener: AnyObject {
    
    func monthScene(didChange currentSelectedDay: CurrentSelectDayModel)
}

protocol MonthScene: Scene where Interactor == MonthSceneInteractor {
}

protocol MonthSceneBuilder: AnyObject {
    
    func makeMonthScene(_ month: CalendarMonth, listener: MonthSceneListener?) -> any MonthScene
}
