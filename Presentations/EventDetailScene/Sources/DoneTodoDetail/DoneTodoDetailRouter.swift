//
//  
//  DoneTodoDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DoneTodoDetailRouting: Routing, Sendable {
    
    func openMap(with query: String, using mapApp: SupportMapApps)
    func openMap(with query: String, afterSelect mapApps: [SupportMapApps])
}

// MARK: - Router

final class DoneTodoDetailRouter: BaseRouterImple, DoneTodoDetailRouting, @unchecked Sendable {
    
    private let selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler
    
    init(selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler) {
        self.selectMapSceneBuilder = selectMapSceneBuilder
    }
}


extension DoneTodoDetailRouter {
    
    private var currentScene: (any DoneTodoDetailScene)? {
        self.scene as? (any DoneTodoDetailScene)
    }
    
    func openMap(with query: String, using mapApp: SupportMapApps) {
        Task { @MainActor in
            guard let url = mapApp.appURL(with: query) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                self.showToast("eventDetail.place::no_map_app".localized())
            }
        }
    }
    
    func openMap(with query: String, afterSelect mapApps: [SupportMapApps]) {
        Task { @MainActor in
            let next = self.selectMapSceneBuilder.makeSelectMapAppDialogScene(query: query, supportMapApps: mapApps)
            self.showBottomSlide(next)
        }
    }
}
