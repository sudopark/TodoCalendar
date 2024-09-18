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
    
    public var shouldConfirmNotCancel: Bool = true
    public var didShowConfirmWith: ConfirmDialogInfo?
    public var didShowConfirmWithCallback: ((ConfirmDialogInfo) -> Void)?
    public func showConfirm(dialog info: ConfirmDialogInfo) {
        self.didShowConfirmWith = info
        self.didShowConfirmWithCallback?(info)
        if shouldConfirmNotCancel {
            info.confirmed?()
        } else {
            info.canceled?()
        }
    }
    
    public var didShowActionSheet: Bool? { self.didShowActionSheetWith != nil }
    public var didShowActionSheetWith: ActionSheetForm?
    public var actionSheetSelectionMocking: ((ActionSheetForm) -> ActionSheetForm.Action?)?
    open func showActionSheet(_ form: ActionSheetForm) {
        self.didShowActionSheetWith = form
        if let selection = self.actionSheetSelectionMocking?(form) {
            selection.selected?()
        }
    }
    
    public var didOpenSafariPath: String?
    public func openSafari(_ path: String) {
        self.didOpenSafariPath = path
    }
}
