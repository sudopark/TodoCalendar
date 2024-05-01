//
//  
//  CalendarPaperRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol CalendarPaperRouting: Routing, Sendable {
    
}

// MARK: - Router

final class CalendarPaperRouter: BaseRouterImple, CalendarPaperRouting, @unchecked Sendable {
    
}


extension CalendarPaperRouter {
    
    private var currentScene: (any CalendarPaperScene)? {
        self.scene as? (any CalendarPaperScene)
    }
    
    // TODO: router implememnts
}
