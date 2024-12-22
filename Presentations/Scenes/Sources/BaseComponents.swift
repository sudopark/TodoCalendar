//
//  BaseComponents.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import Toaster

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

public struct ActionSheetForm: @unchecked Sendable {
    
    public struct Action: @unchecked Sendable {
        
        public enum Style {
            case `default`
            case cancel
            case destructive
        }
        
        public let text: String
        public var style: Style
        public let selected: (() -> Void)?
        
        public init(
            _ text: String,
            style: Style = .default,
            _ selected: (() -> Void)? = nil
        ) {
            self.text = text
            self.style = style
            self.selected = selected
        }
    }
    
    public var title: String?
    public var message: String?
    public var actions: [Action] = []
    
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
    func showActionSheet(_ form: ActionSheetForm)
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
        guard (error as? ServerErrorModel)?.code != .cancelled else { return }
        logger.log(level: .error, "\(error)")
        
        let defaultErrorMessage = "common.errorMessage".localized()
        let message = error.errorMessage
            .map { "\(defaultErrorMessage)\n\n(\($0))" } ?? defaultErrorMessage
        
        let info = ConfirmDialogInfo()
            |> \.message .~ pure(message)
            |> \.confirmText .~ "common.confirm".localized()
            |> \.withCancel .~ false
        self.showConfirm(dialog: info)
    }
    
    public func showToast(_ message: String) {
        Task { @MainActor in
            let toast = Toast(text: message)
            toast.show()
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
    
    public func showActionSheet(_ form: ActionSheetForm) {
        Task { @MainActor in
            
            assert(!form.actions.isEmpty)
            
            let sheet = UIAlertController(
                title: form.title, message: form.message, preferredStyle: .actionSheet
            )
            form.actions.forEach { ac in
                let action = UIAlertAction(title: ac.text, style: ac.style.uiStyle) { _ in
                    ac.selected?()
                }
                sheet.addAction(action)
            }
            
            self.scene?.present(sheet, animated: true)
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

private extension ActionSheetForm.Action.Style {
    
    var uiStyle: UIAlertAction.Style {
        switch self {
        case .cancel: return .cancel
        case .default: return .default
        case .destructive: return .destructive
        }
    }
}

private extension Error {
    
    var errorMessage: String? {
        switch self {
        case let runtime as RuntimeError:
            return runtime.message
        case let server as ServerErrorModel:
            return server.message
        default: return self.localizedDescription
        }
    }
}
