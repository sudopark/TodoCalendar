//
//  MonthScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//

import Foundation
import Domain
import Scenes


// MARK: - MonthScene

protocol MonthSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}

protocol MonthScene: Scene where Interactor == MonthSceneInteractor {
}

protocol MonthSceneBuilder: AnyObject {
    
    func makeMonthScene(_ month: CalendarMonth) -> any MonthScene
}
