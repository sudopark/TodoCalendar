//
//  
//  SelectEventNotificationTimeBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - SelectEventNotificationTimeSceneBuilerImple

final class SelectEventNotificationTimeSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SelectEventNotificationTimeSceneBuilerImple: SelectEventNotificationTimeSceneBuiler {
    
    @MainActor
    func makeSelectEventNotificationTimeScene(
        isForAllDay: Bool,
        startWith select: [EventNotificationTimeOption],
        eventTimeComponents: DateComponents,
        listener: (any SelectEventNotificationTimeSceneListener)?
    ) -> any SelectEventNotificationTimeScene {
        
        let viewModel = SelectEventNotificationTimeViewModelImple(
            isForAllDay: isForAllDay,
            startWith: select,
            eventTimeComponents: eventTimeComponents,
            eventNotificationSettingUsecase: usecaseFactory.makeEventNotificationSettingUsecase(),
            notificationPermissionUsecase: usecaseFactory.makeNotificationPermissionUsecase()
        )
        
        let viewController = SelectEventNotificationTimeViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventNotificationTimeRouter(
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
