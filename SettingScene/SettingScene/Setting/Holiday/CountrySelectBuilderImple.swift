//
//  
//  CountrySelectBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - CountrySelectSceneBuilerImple

final class CountrySelectSceneBuilerImple {
    
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


extension CountrySelectSceneBuilerImple: CountrySelectSceneBuiler {
    
    @MainActor
    func makeCountrySelectScene() -> any CountrySelectScene {
        
        let viewModel = CountrySelectViewModelImple(
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase()
        )
        
        let viewController = CountrySelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = CountrySelectRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
