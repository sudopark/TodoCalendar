//
//  Scenes+Calendar.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain


// MARK: - CalendarScene

public protocol CalendarSceneInteractor: Sendable, AnyObject {
    
    func moveFocusToToday()
}

public protocol CalendarSceneListener: Sendable, AnyObject {
    
    func calendarScene(
        focusChangedTo month: CalendarMonth,
        isCurrentYear: Bool,
        isCurrentDay: Bool
    )
}

public protocol CalendarScene: Scene where Interactor == any CalendarSceneInteractor {
    
    @MainActor
    func addChildMonths(_ monthScenes: [any Scene])
    
    @MainActor
    func changeFocus(at index: Int)
}

public protocol CalendarSceneBuilder {
    
    @MainActor
    func makeCalendarScene(
        listener: (any CalendarSceneListener)?
    ) -> any CalendarScene
}
