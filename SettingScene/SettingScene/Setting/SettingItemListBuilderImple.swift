//
//  
//  SettingItemListBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SettingItemListSceneBuilerImple

final class SettingItemListSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    private let appearanceSceneBuilder: any AppearanceSettingSceneBuiler
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    
    init(
        viewAppearance: ViewAppearance,
        appearanceSceneBuilder: any AppearanceSettingSceneBuiler,
        holidayListSceneBuilder: any HolidayListSceneBuiler
    ) {
        self.viewAppearance = viewAppearance
        self.appearanceSceneBuilder = appearanceSceneBuilder
        self.holidayListSceneBuilder = holidayListSceneBuilder
    }
}


extension SettingItemListSceneBuilerImple: SettingItemListSceneBuiler {
    
    @MainActor
    func makeSettingItemListScene() -> any SettingItemListScene {
        
        let viewModel = SettingItemListViewModelImple(
            
        )
        
        let viewController = SettingItemListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SettingItemListRouter(
            appearanceSceneBuilder: self.appearanceSceneBuilder,
            holidayListSceneBuilder: self.holidayListSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
