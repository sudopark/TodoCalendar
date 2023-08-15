//
//  ___FILEHEADER___
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ___VARIABLE_sceneName___Routing: Routing, Sendable { }

// MARK: - Router

// TODO: compose next Scene Builders protocol
typealias ___VARIABLE_sceneName___NextSceneBuilders = EmptyBuilder

final class ___VARIABLE_sceneName___Router: BaseRouterImple<___VARIABLE_sceneName___NextSceneBuilders>, ___VARIABLE_sceneName___Routing, @unchecked Sendable { }


extension ___VARIABLE_sceneName___Router {
    
    private var currentScene: (any ___VARIABLE_sceneName___Scene)? {
        self.scene as? (any ___VARIABLE_sceneName___Scene)
    }
    
    // TODO: router implememnts
}
