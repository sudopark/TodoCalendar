//
//  EnvironmentStorage.swift
//  Repository
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation

public protocol EnvironmentStorage: AnyObject, Sendable {
    
    func load<T: Decodable>(_ key: String) -> T?
    func update<T: Encodable>(_ key: String, _ value: T)
    func remove(_ key: String)
}


public final class UserDefaultEnvironmentStorageImple: EnvironmentStorage, @unchecked Sendable {
    
    private let userDefaults: UserDefaults
    
    public init(
        suiteName: String? = nil
    ) {
        self.userDefaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        
        switch T.self {
        case is Bool.Type:
            return self.userDefaults.bool(forKey: key) as? T
            
        case is Int.Type:
            return self.userDefaults.integer(forKey: key) as? T
            
        case is Float.Type:
            return self.userDefaults.float(forKey: key) as? T
            
        case is Double.Type:
            return self.userDefaults.double(forKey: key) as? T
            
        case is String.Type:
            return self.userDefaults.string(forKey: key) as? T
            
        default:
            return self.userDefaults.string(forKey: key)
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        
        switch T.self {
        case is Bool.Type:
            self.userDefaults.setValue(value, forKey: key)
        case is Int.Type:
            self.userDefaults.setValue(value, forKey: key)
        case is Float.Type:
            self.userDefaults.setValue(value, forKey: key)
        case is Double.Type:
            self.userDefaults.setValue(value, forKey: key)
        case is String.Type:
            self.userDefaults.setValue(value, forKey: key)
            
        default:
            guard let data = try? JSONEncoder().encode(value),
                  let dataText = String(data: data, encoding: .utf8)
            else { return }
            self.userDefaults.setValue(dataText, forKey: key)
        }
    }
    
    public func remove(_ key: String) {
        self.userDefaults.removeObject(forKey: key)
    }
}
