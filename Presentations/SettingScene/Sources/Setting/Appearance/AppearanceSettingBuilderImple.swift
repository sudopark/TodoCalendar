//
//  
//  AppearanceSettingBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - AppearanceSettingSceneBuilerImple

final class AppearanceSettingSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let colorThemeSelectSceneBuiler: any ColorThemeSelectSceneBuiler
    private let timeZoneSelectSceneBuilder: any TimeZoneSelectSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        colorThemeSelectSceneBuiler: any ColorThemeSelectSceneBuiler,
        timeZoneSelectSceneBuilder: any TimeZoneSelectSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.colorThemeSelectSceneBuiler = colorThemeSelectSceneBuiler
        self.timeZoneSelectSceneBuilder = timeZoneSelectSceneBuilder
    }
}


extension AppearanceSettingSceneBuilerImple: AppearanceSettingSceneBuiler {
    
    @MainActor
    func makeAppearanceSettingScene(
        inital setting: CalendarAppearanceSettings
    ) -> any AppearanceSettingScene {
        
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        
        let viewModel = AppearanceSettingViewModelImple(
            setting: setting,
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        
        let calendarSectionViewModel = CalendarSectionViewModelImple(
            setting: .init(setting),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        
        let eventOnCalendarViewModel = EventOnCalendarViewModelImple(
            setting: .init(setting),
            uiSettingUsecase: uiSettingUsecase
        )
        
        let eventListSettingViewModel = EventListAppearnaceSettingViewModelImple(
            setting: .init(setting),
            uiSettingUsecase: uiSettingUsecase
        )
        
        let viewController = AppearanceSettingViewController(
            initial: setting,
            viewModel: viewModel,
            calendarSectionViewModel: calendarSectionViewModel,
            eventOnCalednarSectionViewModel: eventOnCalendarViewModel,
            eventListAppearanceSettingViewModel: eventListSettingViewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = AppearanceSettingRouter(
            colorThemeSelectSceneBuiler: self.colorThemeSelectSceneBuiler,
            timeZoneSelectBuilder: self.timeZoneSelectSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        eventOnCalendarViewModel.router = router
        eventListSettingViewModel.router = router
        calendarSectionViewModel.router = router
        
        return viewController
    }
}
