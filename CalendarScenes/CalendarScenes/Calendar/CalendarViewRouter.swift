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
    func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarPaperSceneInteractor]
}

final class CalendarViewRouterImple: BaseRouterImple, CalendarViewRouting, @unchecked Sendable {
    
    private let paperSceneBuilder: CalendarPaperSceneBuiler
    init(_ paperSceneBuilder: CalendarPaperSceneBuiler) {
        self.paperSceneBuilder = paperSceneBuilder
    }
    private var currentScene: (any CalendarScene)? { self.scene as? (any CalendarScene) }
    
    @MainActor
    func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarPaperSceneInteractor] {
        guard let current = self.currentScene else { return [] }
        
        let childScenes = months.map { self.paperSceneBuilder.makeCalendarPaperScene($0) }
        current.addChildMonths(childScenes)
        return childScenes.compactMap { $0.interactor }
    }
}
