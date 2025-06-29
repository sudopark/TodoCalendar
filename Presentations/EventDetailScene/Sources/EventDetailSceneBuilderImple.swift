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
    private let googleCalendarEventDetailSceneBuilder: any GoogleCalendarEventDetailSceneBuiler
    private let settingSceneBuilder: any SettingSceneBuiler
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        googleCalendarEventDetailSceneBuilder: any GoogleCalendarEventDetailSceneBuiler,
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.googleCalendarEventDetailSceneBuilder = googleCalendarEventDetailSceneBuilder
        self.settingSceneBuilder = settingSceneBuilder
    }
}

extension EventDetailSceneBuilderImple: EventDetailSceneBuilder {
    
    @MainActor
    public func makeNewEventScene(_ params: MakeEventParams) -> any EventDetailScene {
        
        let viewModel = AddEventViewModelImple(
            params: params,
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsease: self.usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            eventDetailDataUsecase: self.usecaseFactory.makeEventDetailDataUsecase(),
            eventSettingUsecase: self.usecaseFactory.makeEventSettingUsecase(),
            eventNotificationSettingUsecase: self.usecaseFactory.makeEventNotificationSettingUsecase()
        )
        
        return self.makeEventDetailScene(viewModel)
    }
    
    @MainActor
    public func makeTodoEventDetailScene(
        _ todoId: String,
        listener: EventDetailSceneListener?
    ) -> any EventDetailScene {
        let viewModel = EditTodoEventDetailViewModelImple(
            todoId: todoId,
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            eventDetailDataUsecase: self.usecaseFactory.makeEventDetailDataUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase()
        )
        viewModel.listener = listener
        return self.makeEventDetailScene(viewModel)
    }
    
    @MainActor
    public func makeScheduleEventDetailScene(
        _ scheduleId: String,
        _ repeatingEventTargetTime: EventTime?,
        listener: EventDetailSceneListener?
    ) -> any EventDetailScene {
        let viewModel = EditScheduleEventDetailViewModelImple(
            scheduleId: scheduleId,
            repeatingEventTargetTime: repeatingEventTargetTime,
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            eventDetailDataUsecase: self.usecaseFactory.makeEventDetailDataUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase()
        )
        viewModel.listener = listener
        return self.makeEventDetailScene(viewModel)
    }
    
    @MainActor
    private func makeEventDetailScene(
        _ viewModel: any EventDetailViewModel
    ) -> any EventDetailScene {
        
        let inputViewModel = EventDetailInputViewModelImple(
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            eventSettingUsecase: self.usecaseFactory.makeEventSettingUsecase(),
            linkPreviewFetchUsecase: self.usecaseFactory.makeLinkPreviewFetchUsecase()
        )
        
        let viewController = EventDetailViewController(
            viewModel: viewModel,
            inputViewModel: inputViewModel,
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
        
        let selectNotificationTimeSceneBuilder = SelectEventNotificationTimeSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let guideSceneBuilder = GuideSceneBuilderImple(
            viewAppearance: self.viewAppearance
        )
        
        let router = EventDetailRouter(
            selectRepeatOptionSceneBuilder: selectOptionBuilder,
            selectEventTagSceneBuilder: selectTagSceneBuilder,
            selectNotificationTimeSceneBuilder: selectNotificationTimeSceneBuilder,
            guideSceneBuilder: guideSceneBuilder
        )
        router.inputViewModel = inputViewModel
        router.scene = viewController
        viewModel.router = router
        inputViewModel.routing = router
        viewModel.attachInput()
        viewController.router = router
        
        return viewController
    }
    
    @MainActor
    public func makeGoogleCalendarDetailScene(
        calendarId: String, eventId: String
    ) -> any GoogleCalendarEventDetailScene {
        return self.googleCalendarEventDetailSceneBuilder.makeGoogleCalendarEventDetailScene(
            calendarId: calendarId, eventId: eventId
        )
    }
}
