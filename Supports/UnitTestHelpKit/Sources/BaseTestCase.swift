//
//  BaseTestCase.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 2023/03/25.
//

import XCTest


open class BaseTestCase: XCTestCase {
    
    public var timeout: TimeInterval = 0.001
    public var timeoutLong: TimeInterval = 0.01
}
