//
//  ServerErrorModel.swift
//  Domain
//
//  Created by sudo.park on 3/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public struct ServerErrorModel: @unchecked Sendable, Decodable {
    
    public enum ErrorCode: String, Sendable, Decodable {
        case unauthorized = "Unauthorized"
    }
    
    var code: ErrorCode?
    var message: String?
    var origin: String?
    
    public init() { }
    
}
