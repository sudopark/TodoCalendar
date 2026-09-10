//
//  FeatureFlag.swift
//  Domain
//
//  Created by sudo.park on 2/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public final class FeatureFlag: @unchecked Sendable {
    
    public enum Flags: Sendable {
        case reservedFlag
    }
    
    private var enableFlags: Set<Flags> = []
    
    private static let shared: FeatureFlag = .init()
    private init() { }
}


extension FeatureFlag {
    
    public static func enable(_ flag: Flags) {
        FeatureFlag.shared.enableFlags.insert(flag)
    }
    
    public static func disable(_ flag: Flags) {
        FeatureFlag.shared.enableFlags.remove(flag)
    }
    
    public static func isEnable(_ flag: Flags) -> Bool {
        return FeatureFlag.shared.enableFlags.contains(flag)
    }
}
