//
//  KeyValueTable.swift
//  Repository
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros


enum KeyValueTableKeys: String {
    case fcmToken = "fcm_token"
}

@Table("KeyValues")
struct KeyValueTable {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let key: String
    
    @Column()
    var value: String?
}

extension KeyValueTable.Entity {
    
    init(_ key: KeyValueTableKeys, value: String? = nil) {
        self.init(key: key.rawValue, value: value)
    }
}
