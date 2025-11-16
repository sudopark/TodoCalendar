//
//  
//  SelectMapAppDialogRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectMapAppDialogRouting: Routing, Sendable {
    
    func openMap(with query: String, using app: SupportMapApps)
}

// MARK: - Router

final class SelectMapAppDialogRouter: BaseRouterImple, SelectMapAppDialogRouting, @unchecked Sendable { }


extension SelectMapAppDialogRouter {
    
    private var currentScene: (any SelectMapAppDialogScene)? {
        self.scene as? (any SelectMapAppDialogScene)
    }
    
    // TODO: router implememnts
    func openMap(with query: String, using app: SupportMapApps) {
        Task { @MainActor in
            guard let url = app.appURL(with: query) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                self.showToast("eventDetail.place::no_map_app".localized())
            }
        }
    }
}
