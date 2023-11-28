//
//  
//  HolidayListBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - HolidayListSceneBuilerImple

final class HolidayListSceneBuilerImple {
    
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


extension HolidayListSceneBuilerImple: HolidayListSceneBuiler {
    
    @MainActor
    func makeHolidayListScene() -> any HolidayListScene {
        
        let viewModel = HolidayListViewModelImple(
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase(),
            calendarSettingUscase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        
        let viewController = HolidayListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = HolidayListRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
