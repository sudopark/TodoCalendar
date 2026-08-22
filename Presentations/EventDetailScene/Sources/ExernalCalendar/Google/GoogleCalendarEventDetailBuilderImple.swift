//
//  
//  GoogleCalendarEventDetailBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventDetailSceneBuilerImple

public final class GoogleCalendarEventDetailSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension GoogleCalendarEventDetailSceneBuilerImple: GoogleCalendarEventDetailSceneBuiler {
    
    @MainActor
    public func makeGoogleCalendarEventDetailScene(
        calendarId: String, accountId: String, eventId: String
    ) -> any GoogleCalendarEventDetailScene {

        let liveActivityToggleViewModel = LiveActivityToggleViewModelImple(
            eventLiveActivityUsecase: self.usecaseFactory.eventLiveActivityUsecase
        )
        let viewModel = GoogleCalendarEventDetailViewModelImple(
            calenadrId: calendarId, accountId: accountId, eventId: eventId,
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            externalCalendarIntegrationUsecase: self.usecaseFactory.externalCalenarIntegrationUsecase,
            daysIntervalCountUsecase: self.usecaseFactory.makeDaysIntervalCountUsecase(),
            liveActivityToggleViewModel: liveActivityToggleViewModel
        )

        let viewController = GoogleCalendarEventDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let selectRepeatOptionSceneBuilder = SelectEventRepeatOptionSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let router = GoogleCalendarEventDetailRouter(
            selectRepeatOptionSceneBuilder: selectRepeatOptionSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewController.router = router
        liveActivityToggleViewModel.router = router

        return viewController
    }
}
