//
//  
//  TimeZoneSelectRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol TimeZoneSelectRouting: Routing, Sendable { }

// MARK: - Router

final class TimeZoneSelectRouter: BaseRouterImple, TimeZoneSelectRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension TimeZoneSelectRouter {
    
    private var currentScene: (any TimeZoneSelectScene)? {
        self.scene as? (any TimeZoneSelectScene)
    }
    
    // TODO: router implememnts
}
