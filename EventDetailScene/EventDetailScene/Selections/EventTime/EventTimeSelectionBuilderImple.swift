//
//  
//  EventTimeSelectionBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventTimeSelectionSceneBuilerImple

final class EventTimeSelectionSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension EventTimeSelectionSceneBuilerImple: EventTimeSelectionSceneBuiler {
    
    @MainActor
    func makeEventTimeSelectionScene() -> any EventTimeSelectionScene {
        
        let viewModel = EventTimeSelectionViewModelImple(
            
        )
        
        let viewController = EventTimeSelectionViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventTimeSelectionRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
