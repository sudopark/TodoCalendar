//
//  Scenes+Calendar.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain


// MARK: - MonthScene

public protocol MonthSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

public protocol MonthScene: Scene where Interactor == MonthSceneInteractor {
}

public protocol MonthSceneBuilder: AnyObject {
    
    func makeMonthScene(_ month: CalendarMonth) -> any MonthScene
}


// MARK: - CalendarScene

public protocol CalendarSceneInteractor: Sendable, AnyObject {
    
    func moveFocusToToday()
}

public protocol CalendarSceneListener: Sendable, AnyObject {
    
    func calendarScene(
        focusChangedTo month: CalendarMonth,
        isCurrentMonth: Bool
    )
}

public protocol CalendarScene: Scene where Interactor == CalendarSceneInteractor {
    
    @MainActor
    func addChildMonths(_ monthScenes: [any MonthScene])
}

public protocol CalendarSceneBuilder {
    
    func makeCalendarScene(
        listener: CalendarSceneListener?
    ) -> any CalendarScene
}
