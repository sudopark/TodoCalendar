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
    private let eventTagDetailSceneBuilder: any EventTagDetailSceneBuiler
    private let eventTagListSceneBuilder: any EventTagListSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventTagDetailSceneBuilder: any EventTagDetailSceneBuiler,
        eventTagListSceneBuilder: any EventTagListSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventTagDetailSceneBuilder = eventTagDetailSceneBuilder
        self.eventTagListSceneBuilder = eventTagListSceneBuilder
    }
}


extension SelectEventTagSceneBuilerImple: SelectEventTagSceneBuiler {
    
    @MainActor
    func makeSelectEventTagScene(
        startWith initail: AllEventTagId,
        listener: SelectEventTagSceneListener?
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
            eventTagDetailSceneBuilder: self.eventTagDetailSceneBuilder,
            eventTagListSceneBuilder: self.eventTagListSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
