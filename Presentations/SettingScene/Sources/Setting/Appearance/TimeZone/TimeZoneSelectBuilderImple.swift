//
//  
//  TimeZoneSelectBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - TimeZoneSelectSceneBuilerImple

final class TimeZoneSelectSceneBuilerImple {
    
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


extension TimeZoneSelectSceneBuilerImple: TimeZoneSelectSceneBuiler {
    
    @MainActor
    func makeTimeZoneSelectScene() -> any TimeZoneSelectScene {
        
        let viewModel = TimeZoneSelectViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        
        let viewController = TimeZoneSelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = TimeZoneSelectRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
