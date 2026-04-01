//
//  AppleCalendarEventDetailBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - AppleCalendarEventDetailSceneBuilderImple

public final class AppleCalendarEventDetailSceneBuilderImple {

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


extension AppleCalendarEventDetailSceneBuilderImple: AppleCalendarEventDetailSceneBuilder {

    @MainActor
    public func makeAppleCalendarEventDetailScene(
        calendarId: String, eventId: String
    ) -> any AppleCalendarEventDetailScene {

        let viewModel = AppleCalendarEventDetailViewModelImple(
            calendarId: calendarId,
            eventId: eventId,
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            daysIntervalCountUsecase: self.usecaseFactory.makeDaysIntervalCountUsecase()
        )

        let viewController = AppleCalendarEventDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let router = AppleCalendarEventDetailRouter()
        router.scene = viewController
        viewModel.router = router

        return viewController
    }
}
