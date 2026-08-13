//
//  AIAgentInputEnterFailReason.swift
//  Domain
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum AIAgentInputEnterFailReason: Error, Equatable {
    case invalidState
    case creditExhausted
}
