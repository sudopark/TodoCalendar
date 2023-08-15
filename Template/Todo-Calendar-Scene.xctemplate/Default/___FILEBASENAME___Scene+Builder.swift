//
//  ___FILEHEADER___
//

import UIKit


// MARK: - ___VARIABLE_sceneName___Scene Interactable & Listenable

//public protocol ___VARIABLE_sceneName___SceneInteractor: AnyObject { }
//
//public protocol ___VARIABLE_sceneName___SceneListener: AnyObject { }

// MARK: - ___VARIABLE_sceneName___Scene

public protocol ___VARIABLE_sceneName___Scene: Scene where Interactor == EmptyInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol ___VARIABLE_sceneName___SceneBuiler: AnyObject {
    
    func make___VARIABLE_sceneName___Scene() -> any ___VARIABLE_sceneName___Scene
}
