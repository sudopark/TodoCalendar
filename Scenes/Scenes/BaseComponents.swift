//
//  BaseComponents.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit


// MARK: - Scene

public protocol Scene: UIViewController {
    associatedtype Interactor
    @MainActor var interactor: Interactor? { get }
}


// MARK: - Router + BaseRouterimple

public protocol Routing: AnyObject {
    // common routing interface
    func showError(_ error: any Error)
    func showToast(_ message: String)
}

open class BaseRouterImple: Routing {
    
    public weak var scene: (any Scene)?
    
    public init() { }
    
    open func showError(_ error: any Error) {
        // TODO: show error
        Task { @MainActor in
            
        }
    }
    
    public func showToast(_ message: String) {
        // TODO: show toast
        Task { @MainActor in
            
        }
    }
}
