//
//  BaseComponents.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Extensions

public struct ConfirmDialogInfo: @unchecked Sendable {
    
    public var title: String?
    public var message: String?
    public var confirmText: String = "common.confirm".localized()
    public var confirmed: (() -> Void)?
    public var withCancel: Bool = true
    public var cancelText: String = "common.cancel".localized()
    public var canceled: (() -> Void)?
    
    public init() { }
}

public struct EmptyInteractor: Sendable { }

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
    func closeScene(animate: Bool, _ dismissed: (@Sendable () -> Void)?)
    func showConfirm(dialog info: ConfirmDialogInfo)
    func openSafari(_ path: String)
}

extension Routing {
    
    public func closeScene(_ dismissed: (@Sendable () -> Void)? = nil) {
        self.closeScene(animate: true, dismissed)
    }
}

open class BaseRouterImple: Routing, @unchecked Sendable {
    
    public weak var scene: (any Scene)?
    
    public init() { }
    
    open func showError(_ error: any Error) {
        // TODO: show error
        Task { @MainActor in
            logger.log(level: .error, "\(error)")
        }
    }
    
    public func showToast(_ message: String) {
        // TODO: show toast
        Task { @MainActor in
            
        }
    }
    
    open func closeScene(animate: Bool, _ dismissed: (@Sendable () -> Void)?) {
        Task { @MainActor in
            self.scene?.dismiss(animated: animate, completion: dismissed)
        }
    }
    
    public func showConfirm(dialog info: ConfirmDialogInfo) {
        Task { @MainActor in
            let title = info.title ?? "common.info".localized()
            assert(info.message != nil, "messaeg should exists")
            
            let controller = UIAlertController(
                title: title,
                message: info.message,
                preferredStyle: .alert
            )
            let confirmAction = UIAlertAction(
                title: info.confirmText,
                style: .default, 
                handler: { _ in info.confirmed?() }
            )
            controller.addAction(confirmAction)
            
            if info.withCancel {
                let cancelAction = UIAlertAction(
                    title: info.cancelText,
                    style: .cancel,
                    handler: { _ in info.canceled?()}
                )
                controller.addAction(cancelAction)
            }
            
            self.scene?.present(controller, animated: true)
        }
    }
    
    public func openSafari(_ path: String) {
        Task { @MainActor in
            
            guard let url = path.asURL() 
            else {
                // TODO: log open failed
                return
            }
            
            UIApplication.shared.open(url)
        }
    }
}
