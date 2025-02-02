//
//  
//  SelectEventTagBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - SelectEventTagSceneBuilerImple

final class SelectEventTagSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let settingSceneBuilder: any SettingSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.settingSceneBuilder = settingSceneBuilder
    }
}


extension SelectEventTagSceneBuilerImple: SelectEventTagSceneBuiler {
    
    @MainActor
    func makeSelectEventTagScene(
        startWith initail: EventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) -> any SelectEventTagScene {
        
        let viewModel = SelectEventTagViewModelImple(
            startWith: initail,
            tagUsecase: usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = SelectEventTagViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventTagRouter(
            settingSceneBuilder: self.settingSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
