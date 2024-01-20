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
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension EventNotificationDefaultTimeOptionSceneBuilerImple: EventNotificationDefaultTimeOptionSceneBuiler {
    
    @MainActor
    func makeEventNotificationDefaultTimeOptionScene() -> any EventNotificationDefaultTimeOptionScene {
        
        let viewModel = EventNotificationDefaultTimeOptionViewModelImple(
            
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
