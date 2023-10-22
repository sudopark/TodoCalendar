//
//  
//  SelectEventRepeatOptionBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import Domain
import CommonPresentation


// MARK: - SelectEventRepeatOptionSceneBuilerImple

final class SelectEventRepeatOptionSceneBuilerImple {
    
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


extension SelectEventRepeatOptionSceneBuilerImple: SelectEventRepeatOptionSceneBuiler {
    
    @MainActor
    func makeSelectEventRepeatOptionScene(
        startTime: Date,
        previousSelected repeating: EventRepeating,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) -> any SelectEventRepeatOptionScene {
        
        let viewModel = SelectEventRepeatOptionViewModelImple(
            startTime: startTime,
            previousSelected: repeating,
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        
        let viewController = SelectEventRepeatOptionViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventRepeatOptionRouter(
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        return viewController
    }
}
