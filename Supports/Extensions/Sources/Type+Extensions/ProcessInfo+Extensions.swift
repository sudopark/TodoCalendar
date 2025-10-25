//
//  ProcessInfo+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 10/7/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


extension ProcessInfo {
    
    
    /// version: 26.0
    public static func isAvailable(_ version: String) -> Bool {
        
        let parts = version.split(separator: ".").compactMap { Int($0) }
        let requireVersion = OperatingSystemVersion(
            majorVersion: parts.first ?? 0,
            minorVersion: parts.count > 1 ? parts[1] : 0,
            patchVersion: parts.count > 2 ? parts[2] : 0
        )
        
        return processInfo.isOperatingSystemAtLeast(requireVersion)
    }
    
    public static func isAvailiOS26() -> Bool {
        return self.isAvailable("26.0")
    }
}
