//
//  StubGoogleCalendarUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubGoogleCalendarUsecase: GoogleCalendarUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var didPrepared = false
    open func prepare() {
        self.didPrepared = true
    }
}
