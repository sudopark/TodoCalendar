//
//  GoogleCalendarEventEditBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventEditSceneBuilerImple

public final class GoogleCalendarEventEditSceneBuilerImple {

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


extension GoogleCalendarEventEditSceneBuilerImple: GoogleCalendarEventEditSceneBuiler {

    @MainActor
    public func makeGoogleCalendarEventEditScene(
        calendarId: String, accountId: String, eventId: String,
        listener: (any GoogleCalendarEventEditSceneListener)?
    ) -> any GoogleCalendarEventEditScene {

        let viewModel = GoogleCalendarEventEditViewModelImple(
            calendarId: calendarId, accountId: accountId, eventId: eventId,
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        viewModel.listener = listener

        let viewController = GoogleCalendarEventEditViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let router = GoogleCalendarEventEditRouter()
        router.scene = viewController
        viewModel.router = router
        viewController.router = router

        return viewController
    }
}
