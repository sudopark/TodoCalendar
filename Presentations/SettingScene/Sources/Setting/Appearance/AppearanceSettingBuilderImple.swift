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
    func makeAppearanceSettingScene(
        inital setting: AppearanceSettings
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
            timeZoneSelectBuilder: self.timeZoneSelectSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        // TOOD: set calendarSectionVM Router
        
        return viewController
    }
}
