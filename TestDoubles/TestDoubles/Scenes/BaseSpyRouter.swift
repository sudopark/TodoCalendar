//
//  BaseSpyRouter.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/09/11.
//

import Foundation
import Scenes


open class BaseSpyRouter: Routing {
    
    public init() { }
    
    public var didShowError: (any Error)?
    public var didShowErrorCallback: ((any Error) -> Void)?
    open func showError(_ error: any Error) {
        self.didShowError = error
        self.didShowErrorCallback?(error)
    }
    
    public var didShowToastWithMessage: String?
    open func showToast(_ message: String) {
        self.didShowToastWithMessage = message
    }
    
    public var didClosed: Bool?
    public var didCloseCallback: (() -> Void)?
    public func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        self.didClosed = true
        dismissed?()
        self.didCloseCallback?()
    }
    
    public var didShowConfirmWith: ConfirmDialogInfo?
    public var didShowConfirmWithCallback: ((ConfirmDialogInfo) -> Void)?
    public func showConfirm(dialog info: ConfirmDialogInfo) {
        self.didShowConfirmWith = info
        self.didShowConfirmWithCallback?(info)
        info.confirmed?()
    }
}
