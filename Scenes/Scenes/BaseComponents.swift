//
//  BaseComponents.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit


// MARK: - SceneInteractors


public final class EmptyInteractor { }

// MARK: - Scene

public protocol Scene: UIViewController {
    associatedtype Interactor
    var interactor: Interactor? { get }
}

extension Scene {
    
    public var interactor: Interactor? { nil }
}


// MARK: - Router + BaseRouterimple

public protocol Routing: AnyObject {
    // common routing interface
}

open class BaseRouterImple<NextScenesBuilder>: Routing {
    
    public final let nextScenesBuilder: NextScenesBuilder
    public weak var scene: (any Scene)?
    
    public init(_ nextScenesBuilder: NextScenesBuilder) {
        self.nextScenesBuilder = nextScenesBuilder
    }
}
