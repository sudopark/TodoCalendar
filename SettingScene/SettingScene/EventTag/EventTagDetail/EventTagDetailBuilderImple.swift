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

public final class EventTagDetailSceneBuilerImple {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension EventTagDetailSceneBuilerImple: EventTagDetailSceneBuiler {
    
    @MainActor
    public func makeEventTagDetailScene(
        originalInfo: OriginalTagInfo?,
        listener: (any EventTagDetailSceneListener)?
    ) -> any EventTagDetailScene {
        
        let viewModel = EventTagDetailViewModelImple(
            originalInfo: originalInfo,
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase()
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
