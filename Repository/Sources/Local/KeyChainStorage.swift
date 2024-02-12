//
//  KeyChainStorage.swift
//  Repository
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import KeychainSwift

public protocol KeyChainStorage: AnyObject, Sendable {
    
    func setupSharedGroup(_ identifier: String)
    func load<T: Decodable>(_ key: String) -> T?
    func update<T: Encodable>(_ key: String, _ value: T)
    func remove(_ key: String)
}


public final class KeyChainStorageImple: KeyChainStorage, @unchecked Sendable {
    
    private let keychain: KeychainSwift
    
    public init(identifier prefix: String) {
        self.keychain = KeychainSwift(keyPrefix: prefix)
    }
}


extension KeyChainStorageImple {
    
    public func setupSharedGroup(_ identifier: String) {
        self.keychain.accessGroup = identifier
    }
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        switch T.self {
        case is Bool.Type:
            return self.keychain.getBool(key) as? T
        case is String.Type:
            return self.keychain.get(key) as? T
        default:
            guard let data: Data = self.keychain.getData(key)
            else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        switch value {
        case let bool as Bool:
            self.keychain.set(bool, forKey: key)
            
        case let string as String:
            self.keychain.set(string, forKey: key)
            
        default:
            guard let data = try? JSONEncoder().encode(value) else { return }
            self.keychain.set(data, forKey: key)
        }
    }
    
    public func remove(_ key: String) {
        self.keychain.delete(key)
    }
}
