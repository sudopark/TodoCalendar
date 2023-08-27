//
//  
//  MainBuilderImple.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Scenes
import CommonPresentation
import CalendarScenes


// MARK: - MainSceneBuilerImple

public final class MainSceneBuilerImple {
    
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


extension MainSceneBuilerImple: MainSceneBuiler {
    
    public func makeMainScene() -> any MainScene {
        
        let viewModel = MainViewModelImple(
            
        )
        
        let viewController = MainViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let nextSceneBuilder = CalendarSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let router = MainRouter(
            nextSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
