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

extension Scene where Interactor == EmptyInteractor {
    
    public var interactor: Interactor? { nil }
}


// MARK: - empty builder

public struct EmptyBuilder {
    public init() { }
}


// MARK: - Router + BaseRouterimple

public protocol Routing: AnyObject {
    // common routing interface
}

open class BaseRouterImple: Routing {
    
    public weak var scene: (any Scene)?
    
    public init() { }
}
