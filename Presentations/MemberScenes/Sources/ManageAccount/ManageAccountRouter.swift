//
//  
//  ManageAccountRouter.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ManageAccountRouting: Routing, Sendable { }

// MARK: - Router

final class ManageAccountRouter: BaseRouterImple, ManageAccountRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: true)
        }
    }
}


extension ManageAccountRouter {
    
    private var currentScene: (any ManageAccountScene)? {
        self.scene as? (any ManageAccountScene)
    }
    
    // TODO: router implememnts
}
