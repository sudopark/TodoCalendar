//
//  KeyedDecodingContainer+TimeStamp.swift
//  RemoteInfraInterface
//
//  Created by sudo.park on 3/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


extension KeyedDecodingContainer {
    
    public func decodeTimeStampBaseDate(_ key: Key) throws -> Date {
        let timeStamp = try self.decode(TimeInterval.self, forKey: key)
        return Date(timeIntervalSince1970: timeStamp)
    }
}
