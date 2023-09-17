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
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let monthSceneBuilder: any MonthSceneBuilder
    private let eventListSceneBuilder: any DayEventListSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        monthSceneBuilder: any MonthSceneBuilder,
        eventListSceneBuilder: any DayEventListSceneBuiler
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
