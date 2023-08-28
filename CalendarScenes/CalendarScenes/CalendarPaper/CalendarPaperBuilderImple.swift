//
//  
//  CalendarPaperBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - CalendarPaperSceneBuilerImple

final class CalendarPaperSceneBuilerImple {
    
    private let viewAppearance: ViewAppearance
    
    init(
        viewAppearance: ViewAppearance
    ) {
        self.viewAppearance = viewAppearance
    }
}


extension CalendarPaperSceneBuilerImple: CalendarPaperSceneBuiler {
    
    func makeCalendarPaperScene() -> any CalendarPaperScene {
        
        let viewModel = CalendarPaperViewModelImple(
            
        )
        
        let viewController = CalendarPaperViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = CalendarPaperRouter()
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
