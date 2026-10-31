//
//  KeyValueTable.swift
//  DBInfraInterface
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros


public enum KeyValueTableKeys: String {
    case fcmToken = "fcm_token"
    case billingUserPlan = "billing_user_plan"
}

@Table("KeyValues")
public struct KeyValueTable {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    public let key: String
    
    @Column()
    public var value: String?
}

extension KeyValueTable.Entity {
    
    public init(_ key: KeyValueTableKeys, value: String? = nil) {
        self.init(key: key.rawValue, value: value)
    }
}
