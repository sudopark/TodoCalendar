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
    
    @MainActor
    func makeCalendarPaperScene(_ month: CalendarMonth) -> any CalendarPaperScene {
        
        let monthComponents = self.monthSceneBuilder.makeSceneComponent(month)
        let eventListComponents = self.eventListSceneBuilder.makeSceneComponent()
        let viewModel = CalendarPaperViewModelImple(
            month: month,
            monthInteractor: monthComponents.viewModel,
            eventListInteractor: eventListComponents.viewModel
        )
        monthComponents.viewModel.attachListener(viewModel)
        
        let viewController = CalendarPaperViewController(
            viewModel: viewModel,
            monthViewModel: monthComponents.viewModel,
            eventListViewModel: eventListComponents.viewModel,
            viewAppearance: self.viewAppearance
        )
        (eventListComponents.router as? BaseRouterImple)?.scene = viewController
        
        let router = CalendarPaperRouter()
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
