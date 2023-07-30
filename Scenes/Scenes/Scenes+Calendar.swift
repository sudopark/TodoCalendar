//
//  Scenes+Calendar.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain


// MARK: - CalendarSingleMonthScene

public protocol CalendarSingleMonthInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

public protocol CalendarSingleMonthScene: Scene where Interactor == CalendarSingleMonthInteractor {
}

public protocol CalendarSingleMonthSceneBuilder: AnyObject {
    
    func makeSingleMonthScene(_ month: CalendarMonth) -> any CalendarSingleMonthScene
}


// MARK: - CalendarPagerScene

public protocol CalendarPagerScene: Scene where Interactor == EmptyInteractor {
    
    func addChildMonths(_ singleMonthScenes: [any CalendarSingleMonthScene])
}

public protocol CalendarPagerSceneBuilder {
    
    func makeCalendarPagerScene() -> any CalendarPagerScene
}
