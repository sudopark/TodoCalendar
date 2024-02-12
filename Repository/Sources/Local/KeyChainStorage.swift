//
//  KeyChainStorage.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol KeyChainStorage: AnyObject, Sendable {
    
    func setupSharedGroup(_ identifier: String)
    func load<T: Decodable>(_ key: String) -> T?
    func update<T: Encodable>(_ key: String, _ value: T)
    func remove(_ key: String)
}
