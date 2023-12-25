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
    private let timeZoneSelectSceneBuilder: any TimeZoneSelectSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        timeZoneSelectSceneBuilder: any TimeZoneSelectSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.timeZoneSelectSceneBuilder = timeZoneSelectSceneBuilder
    }
}


extension AppearanceSettingSceneBuilerImple: AppearanceSettingSceneBuiler {
    
    @MainActor
    func makeAppearanceSettingScene() -> any AppearanceSettingScene {
        
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        
        let viewModel = AppearanceSettingViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        
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
            timeZoneSelectBuilder: self.timeZoneSelectSceneBuilder
        )
        router.calendarInteractor = calendarSectionViewModel
        router.eventOnCalendarInteractor = eventOnCalendarViewModel
        router.eventListInteractor = eventListSettingViewModel
        
        router.scene = viewController
        viewModel.router = router
        // TOOD: set calendarSectionVM Router
        
        return viewController
    }
}
