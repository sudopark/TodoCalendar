//
//  
//  DoneTodoEventListRouter.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DoneTodoEventListRouting: Routing, Sendable { 
    
    func showSelectRemoveDoneTodoRangePicker(
        _ selected: @escaping (RemoveDoneTodoRange) -> Void
    )
}

// MARK: - Router

final class DoneTodoEventListRouter: BaseRouterImple, DoneTodoEventListRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        self.currentScene?.dismiss(animated: true)
    }
}


extension DoneTodoEventListRouter {
    
    private var currentScene: (any DoneTodoEventListScene)? {
        self.scene as? (any DoneTodoEventListScene)
    }
    
    func showSelectRemoveDoneTodoRangePicker(
        _ selected: @escaping (RemoveDoneTodoRange) -> Void
    ) {
        // TODO:
    }
}
