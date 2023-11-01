//
//  EventDetailSceneBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


public final class EventDetailSceneBuilderImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let settingSceneBuilder: any SettingSceneBuiler
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.settingSceneBuilder = settingSceneBuilder
    }
}

extension EventDetailSceneBuilderImple: EventDetailSceneBuilder {
    
    @MainActor
    public func makeNewEventScene(isTodo: Bool) -> any EventDetailScene {
        
        let viewModel = AddEventViewModelImple(
            isTodo: isTodo,
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsease: self.usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            eventDetailDataUsecase: self.usecaseFactory.makeEventDetailDataUsecase()
        )
        
        let viewController = EventDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let selectOptionBuilder = SelectEventRepeatOptionSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let selectTagSceneBuilder = SelectEventTagSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            settingSceneBuilder: self.settingSceneBuilder
        )
        
        let router = EventDetailRouter(
            selectRepeatOptionSceneBuilder: selectOptionBuilder,
            selectEventTagSceneBuilder: selectTagSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
