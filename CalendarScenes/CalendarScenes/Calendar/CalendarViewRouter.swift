//
//  CalendarPagerViewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/30.
//

import Foundation
import Domain
import Scenes

protocol CalendarViewRouting: Routing, Sendable {
    
    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [MonthSceneInteractor]
}

final class CalendarViewRouterImple: BaseRouterImple, CalendarViewRouting, @unchecked Sendable {
    
    private let monthSceneBuilder: MonthSceneBuilder
    init(_ monthSceneBuilder: MonthSceneBuilder) {
        self.monthSceneBuilder = monthSceneBuilder
    }
    private var currentScene: (any CalendarScene)? { self.scene as? (any CalendarScene) }
    
    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [MonthSceneInteractor] {
        guard let current = self.currentScene else { return [] }
        let childScenes = months.map { self.monthSceneBuilder.makeMonthScene($0) }
        current.addChildMonths(childScenes)
        return childScenes.compactMap { $0.interactor }
    }
}
