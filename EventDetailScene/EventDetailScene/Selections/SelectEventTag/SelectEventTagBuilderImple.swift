//
//  
//  SelectEventTagBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SelectEventTagSceneBuilerImple

final class SelectEventTagSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension SelectEventTagSceneBuilerImple: SelectEventTagSceneBuiler {
    
    @MainActor
    func makeSelectEventTagScene() -> any SelectEventTagScene {
        
        let viewModel = SelectEventTagViewModelImple(
            
        )
        
        let viewController = SelectEventTagViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventTagRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
