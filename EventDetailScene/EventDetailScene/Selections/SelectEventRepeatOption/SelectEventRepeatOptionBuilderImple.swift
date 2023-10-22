//
//  
//  SelectEventRepeatOptionBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SelectEventRepeatOptionSceneBuilerImple

final class SelectEventRepeatOptionSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension SelectEventRepeatOptionSceneBuilerImple: SelectEventRepeatOptionSceneBuiler {
    
    @MainActor
    func makeSelectEventRepeatOptionScene() -> any SelectEventRepeatOptionScene {
        
        let viewModel = SelectEventRepeatOptionViewModelImple(
            
        )
        
        let viewController = SelectEventRepeatOptionViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventRepeatOptionRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
