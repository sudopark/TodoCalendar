//
//  
//  CalendarPaperBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - CalendarPaperSceneBuilerImple

final class CalendarPaperSceneBuilerImple {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let monthSceneBuilder: MonthSceneBuilder
    private let eventListSceneBuilder: DayEventListSceneBuiler
    
    init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance,
        monthSceneBuilder: MonthSceneBuilder,
        eventListSceneBuilder: DayEventListSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.monthSceneBuilder = monthSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
    }
}


extension CalendarPaperSceneBuilerImple: CalendarPaperSceneBuiler {
    
    func makeCalendarPaperScene(_ month: CalendarMonth) -> any CalendarPaperScene {
        
        let viewModel = CalendarPaperViewModelImple(month: month)
        
        let viewController = CalendarPaperViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = CalendarPaperRouter(
            monthSceneBuilder: self.monthSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
