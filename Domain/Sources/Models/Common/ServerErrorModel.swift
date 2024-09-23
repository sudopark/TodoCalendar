//
//  ServerErrorModel.swift
//  Domain
//
//  Created by sudo.park on 3/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public struct ServerErrorModel: Error, @unchecked Sendable, Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case origin
    }
    
    public enum ErrorCode: String, Sendable, Decodable {
        case unauthorized = "Unauthorized"
        case invalidAccessKey = "InvalidAccessKey"
        case cancelled
    }
    
    public var code: ErrorCode?
    public var codeRawValue: String?
    public var message: String?
    public var origin: String?
    public var rawError: (any Error)?
    public var statusCode: Int?
    
    public init() { }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let code = try? container.decode(ErrorCode.self, forKey: .code) {
            self.code = code
        } else {
            self.codeRawValue = try? container.decode(String.self, forKey: .code)
        }
        self.message = try? container.decode(String.self, forKey: .message)
        self.origin = try? container.decode(String.self, forKey: .origin)
    }
}
