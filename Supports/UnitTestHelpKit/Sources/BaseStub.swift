//
//  BaseStub.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


public protocol BaseStub { }

extension BaseStub {
    
    public func checkShouldFail(_ flag: Bool, customError: (any Error)? = nil) throws {
        guard flag else { return }
        throw customError ?? TestError()
    }
}
