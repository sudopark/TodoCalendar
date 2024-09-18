//
//  ___FILEHEADER___
//

import UIKit
import Scenes


// MARK: - ___VARIABLE_sceneName___Scene Interactable & Listenable

protocol ___VARIABLE_sceneName___SceneInteractor: AnyObject { }
//
//public protocol ___VARIABLE_sceneName___SceneListener: AnyObject { }

// MARK: - ___VARIABLE_sceneName___Scene

protocol ___VARIABLE_sceneName___Scene: Scene where Interactor == any ___VARIABLE_sceneName___SceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol ___VARIABLE_sceneName___SceneBuiler: AnyObject {
    
    @MainActor
    func make___VARIABLE_sceneName___Scene() -> any ___VARIABLE_sceneName___Scene
}
