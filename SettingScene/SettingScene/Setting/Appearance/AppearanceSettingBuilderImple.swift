//
//  
//  AppearanceSettingBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - AppearanceSettingSceneBuilerImple

final class AppearanceSettingSceneBuilerImple {
    
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


extension AppearanceSettingSceneBuilerImple: AppearanceSettingSceneBuiler {
    
    @MainActor
    func makeAppearanceSettingScene() -> any AppearanceSettingScene {
        
        let viewModel = AppearanceSettingViewModelImple(
            
        )
        
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let calendarSectionViewModel = CalendarSectionViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        
        let eventOnCalendarViewModel = EventOnCalendarViewModelImple(
            uiSettingUsecase: uiSettingUsecase
        )
        
        let eventListSettingViewModel = EventListAppearnaceSettingViewModelImple(
            uiSettingUsecase: uiSettingUsecase
        )
        
        let viewController = AppearanceSettingViewController(
            viewModel: viewModel,
            calendarSectionViewModel: calendarSectionViewModel,
            eventOnCalednarSectionViewModel: eventOnCalendarViewModel,
            eventListAppearanceSettingViewModel: eventListSettingViewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = AppearanceSettingRouter(
        )
        router.scene = viewController
        viewModel.router = router
        // TOOD: set calendarSectionVM Router
        
        return viewController
    }
}
