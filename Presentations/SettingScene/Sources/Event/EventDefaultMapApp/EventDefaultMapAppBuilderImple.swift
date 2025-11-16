//
//  
//  EventDefaultMapAppBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventDefaultMapAppSceneBuilerImple

final class EventDefaultMapAppSceneBuilerImple {
    
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


extension EventDefaultMapAppSceneBuilerImple: EventDefaultMapAppSceneBuiler {
    
    @MainActor
    func makeEventDefaultMapAppScene() -> any EventDefaultMapAppScene {
        
        let viewModel = EventDefaultMapAppViewModelImple(
            eventSettingUsecase: self.usecaseFactory.makeEventSettingUsecase()
        )
        
        let viewController = EventDefaultMapAppViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventDefaultMapAppRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
