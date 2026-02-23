//
//  
//  DoneTodoDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes


// MARK: - Builder + DependencyInjector Extension

protocol DoneTodoDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeDoneTodoDetailScene(
        uuid: String,
        listener: (any DoneTodoDetailSceneListener)?
    ) -> any DoneTodoDetailScene
}
