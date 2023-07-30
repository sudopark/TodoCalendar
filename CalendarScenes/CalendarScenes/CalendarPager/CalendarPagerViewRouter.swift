//
//  CalendarPagerViewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/30.
//

import Foundation
import Domain
import Scenes

protocol CalendarPagerViewRouting: Routing, Sendable {
    
    func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarSingleMonthInteractor]
}


typealias NextSceneBuilders = CalendarSingleMonthSceneBuilder

final class CalendarPagerViewRouterImple: BaseRouterImple<NextSceneBuilders>, CalendarPagerViewRouting, @unchecked Sendable {
    
    private var currentScene: (any CalendarPagerScene)? { self.scene as? (any CalendarPagerScene) }
    
    func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarSingleMonthInteractor] {
        guard let current = self.currentScene else { return [] }
        let childScenes = months.map { self.nextScenesBuilder.makeSingleMonthScene($0) }
        current.addChildMonths(childScenes)
        return childScenes.compactMap { $0.interactor }
    }
}
