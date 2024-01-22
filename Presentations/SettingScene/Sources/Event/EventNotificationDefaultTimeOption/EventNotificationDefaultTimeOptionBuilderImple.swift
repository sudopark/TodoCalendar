//
//  
//  EventNotificationDefaultTimeOptionBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventNotificationDefaultTimeOptionSceneBuilerImple

final class EventNotificationDefaultTimeOptionSceneBuilerImple {
    
    private let usecaesFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaesFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaesFactory = usecaesFactory
        self.viewAppearance = viewAppearance
    }
}


extension EventNotificationDefaultTimeOptionSceneBuilerImple: EventNotificationDefaultTimeOptionSceneBuiler {
    
    @MainActor
    func makeEventNotificationDefaultTimeOptionScene(
        forAllDay: Bool
    ) -> any EventNotificationDefaultTimeOptionScene {
        
        let viewModel = EventNotificationDefaultTimeOptionViewModelImple(
            forAllDay: forAllDay,
            notificationPermissionUsecase: usecaesFactory.makeNotificationPermissionUsecase(),
            eventNotificationSettingUsecase: usecaesFactory.makeEventNotificationSettingUsecase()
        )
        
        let viewController = EventNotificationDefaultTimeOptionViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventNotificationDefaultTimeOptionRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
