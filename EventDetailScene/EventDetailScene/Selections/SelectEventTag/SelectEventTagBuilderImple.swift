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
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SelectEventTagSceneBuilerImple: SelectEventTagSceneBuiler {
    
    @MainActor
    func makeSelectEventTagScene(
        startWith initail: AllEventTagId
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
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
