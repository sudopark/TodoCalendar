//
//  
//  AddEventBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - AddEventSceneBuilerImple

final class AddEventSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
    }
}


extension AddEventSceneBuilerImple: AddEventSceneBuiler {
    
    @MainActor
    func makeAddEventScene() -> any AddEventScene {
        
        let viewModel = AddEventViewModelImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsease: self.usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        
        let viewController = AddEventViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = AddEventRouter(
            selectRepeatOptionSceneBuilder: selectRepeatOptionSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
