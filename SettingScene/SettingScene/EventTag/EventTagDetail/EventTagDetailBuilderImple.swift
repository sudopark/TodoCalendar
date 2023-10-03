//
//  
//  EventTagDetailBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventTagDetailSceneBuilerImple

final class EventTagDetailSceneBuilerImple {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension EventTagDetailSceneBuilerImple: EventTagDetailSceneBuiler {
    
    @MainActor
    func makeEventTagDetailScene(
        originalInfo: OriginalTagInfo?,
        listener: EventTagDetailSceneListener?
    ) -> any EventTagDetailScene {
        
        let viewModel = EventTagDetailViewModelImple(
            originalInfo: originalInfo,
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = EventTagDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventTagDetailRouter(
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
