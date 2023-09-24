//
//  
//  EventTagListBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventTagListSceneBuilerImple

final class EventTagListSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension EventTagListSceneBuilerImple: EventTagListSceneBuiler {
    
    @MainActor
    func makeEventTagListScene() -> any EventTagListScene {
        
        let viewModel = EventTagListViewModelImple(
            
        )
        
        let viewController = EventTagListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventTagListRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
