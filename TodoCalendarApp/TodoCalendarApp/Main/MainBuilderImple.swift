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


// MARK: - MainSceneBuilerImple

public final class MainSceneBuilerImple {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let calendarSceneBulder: CalendarSceneBuilder
    
    public init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance,
        calendarSceneBulder: CalendarSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.calendarSceneBulder = calendarSceneBulder
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
        
        let router = MainRouter(self.calendarSceneBulder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
