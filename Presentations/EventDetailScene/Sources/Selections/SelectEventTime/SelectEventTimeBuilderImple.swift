//
//  
//  SelectEventTimeBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SelectEventTimeSceneBuilerImple

final class SelectEventTimeSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension SelectEventTimeSceneBuilerImple: SelectEventTimeSceneBuiler {
    
    @MainActor
    func makeSelectEventTimeScene(
        startWith previousTime: SelectedTime?,
        at timeZone: TimeZone
    ) -> any SelectEventTimeScene {
        
        let viewModel = SelectEventTimeViewModelImple(
            startWith: previousTime, at: timeZone
        )
        
        let viewController = SelectEventTimeViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectEventTimeRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
