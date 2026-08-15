//
//  EventListCellEventHanleViewModelBuilder.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


protocol EventListCellEventHanleViewModelBuilder {
    
    var viewModel: any EventListCellEventHanleViewModel { get }
    var router: any EventListCellEventHanleRouting { get }
}


final class EventListCellEventHanleViewModelBuilderImple: EventListCellEventHanleViewModelBuilder {
    
    private let usecaseFactory: any UsecaseFactory
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    
    let viewModel: any EventListCellEventHanleViewModel
    let router: any EventListCellEventHanleRouting
    init(
        usecaseFactory: any UsecaseFactory,
        eventDetailSceneBuilder: any EventDetailSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        
        let viewModel = EventListCellEventHanleViewModelImple(
            todoEventUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase()
        )
        let router = EventListCellEventHanleRouter(
            eventDetailSceneBuilder: eventDetailSceneBuilder
        )
        self.viewModel = viewModel
        viewModel.router = router
        router.eventDetailListener = viewModel
        self.router = router
    }
}
