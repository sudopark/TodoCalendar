//
//  
//  FeedbackPostBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - FeedbackPostSceneBuilerImple

final class FeedbackPostSceneBuilerImple {
    
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


extension FeedbackPostSceneBuilerImple: FeedbackPostSceneBuiler {
    
    @MainActor
    func makeFeedbackPostScene() -> any FeedbackPostScene {
        
        let viewModel = FeedbackPostViewModelImple(
            feedbackUsecase: self.usecaseFactory.makeFeedbackUsecase()
        )
        
        let viewController = FeedbackPostViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = FeedbackPostRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
