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
    private let selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler,
        selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
        self.selectEventTagSceneBuilder = selectEventTagSceneBuilder
    }
}


extension AddEventSceneBuilerImple: AddEventSceneBuiler {
    
    @MainActor
    func makeAddEventScene() -> any AddEventScene {
        
        let viewModel = AddEventViewModelImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsease: self.usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            eventDetailDataUsecase: self.usecaseFactory.makeEventDetailDataUsecase()
        )
        
        let viewController = AddEventViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = AddEventRouter(
            selectRepeatOptionSceneBuilder: self.selectRepeatOptionSceneBuilder,
            selectEventTagSceneBuilder: self.selectEventTagSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
