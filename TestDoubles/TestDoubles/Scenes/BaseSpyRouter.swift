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
    
    public var didShowError: Error?
    public var didShowErrorCallback: ((Error) -> Void)?
    open func showError(_ error: Error) {
        self.didShowError = error
        self.didShowErrorCallback?(error)
    }
    
    public var didShowToastWithMessage: String?
    open func showToast(_ message: String) {
        self.didShowToastWithMessage = message
    }
}
