//
//  Scenes+Calendar.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain


// MARK: - SingleMonthScene

public protocol SingleMonthSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

public protocol SingleMonthScene: Scene where Interactor == SingleMonthSceneInteractor {
}

public protocol SingleMonthSceneBuilder: AnyObject {
    
    func makeSingleMonthScene(_ month: CalendarMonth) -> any SingleMonthScene
}


// MARK: - CalendarScene

public protocol CalendarScene: Scene where Interactor == EmptyInteractor {
    
    func addChildMonths(_ singleMonthScenes: [any SingleMonthScene])
}

public protocol CalendarSceneBuilder {
    
    func makeCalendarScene() -> any CalendarScene
}