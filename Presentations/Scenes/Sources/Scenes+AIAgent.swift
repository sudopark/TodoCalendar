//
//  Scenes+AIAgent.swift
//  Scenes
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


// MARK: - AIAgentScene

public protocol AIAgentSceneInteractor: AnyObject { }

public protocol AIAgentScene: Scene where Interactor == any AIAgentSceneInteractor { }

public protocol AIAgentSceneBuilder: AnyObject {
    @MainActor
    func makeAIAgentScene() -> any AIAgentScene
}
