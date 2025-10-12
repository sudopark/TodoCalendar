//
//  
//  HolidayEventDetailBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - HolidayEventDetailSceneBuilerImple

public final class HolidayEventDetailSceneBuilerImple {
    
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


extension HolidayEventDetailSceneBuilerImple: HolidayEventDetailSceneBuiler {
    
    @MainActor
    public func makeHolidayEventDetailScene(uuid: String) -> any HolidayEventDetailScene {
        
        let viewModel = HolidayEventDetailViewModelImple(
            uuid: uuid,
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase()
        )
        
        let viewController = HolidayEventDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = HolidayEventDetailRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
