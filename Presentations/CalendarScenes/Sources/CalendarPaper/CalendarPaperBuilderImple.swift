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
    private let eventListCellEventHanleViewModelBuilder: any EventListCellEventHanleViewModelBuilder
    private let pendingCompleteTodoState: PendingCompleteTodoState
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        monthSceneBuilder: any MonthSceneBuilder,
        eventListSceneBuilder: any DayEventListSceneBuiler,
        eventListCellEventHanleViewModelBuilder: any EventListCellEventHanleViewModelBuilder,
        pendingCompleteTodoState: PendingCompleteTodoState
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.monthSceneBuilder = monthSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
        self.eventListCellEventHanleViewModelBuilder = eventListCellEventHanleViewModelBuilder
        self.pendingCompleteTodoState = pendingCompleteTodoState
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
            eventListCellEventHandleViewModel: eventListCellEventHanleViewModelBuilder.viewModel,
            pendingCompleteTodoState: pendingCompleteTodoState,
            viewAppearance: self.viewAppearance
        )
        (eventListComponents.router as? BaseRouterImple)?.scene = viewController
        
        let router = CalendarPaperRouter()
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
