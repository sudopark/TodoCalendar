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

public final class EventTagListSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension EventTagListSceneBuilerImple: EventTagListSceneBuiler {
    
    @MainActor
    public func makeEventTagListScene(
        listener: (any EventTagListSceneListener)?
    ) -> any EventTagListScene {
        
        let viewModel = EventTagListViewModelImple(
            tagUsecase: self.usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = EventTagListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let tagDetailBuilder = EventTagDetailSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let router = EventTagListRouter(
            tagDetailSceneBuilder: tagDetailBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
