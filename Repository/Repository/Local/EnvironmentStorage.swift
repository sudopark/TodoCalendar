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


public final class UserDefaultEnvironmentStorageImple: EnvironmentStorage {
    
    public init() { }
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        
        switch T.self {
        case is Bool.Type:
            return UserDefaults.standard.bool(forKey: key) as? T
            
        case is Int.Type:
            return UserDefaults.standard.integer(forKey: key) as? T
            
        case is Float.Type:
            return UserDefaults.standard.float(forKey: key) as? T
            
        case is Double.Type:
            return UserDefaults.standard.double(forKey: key) as? T
            
        case is String.Type:
            return UserDefaults.standard.string(forKey: key) as? T
            
        default:
            return UserDefaults.standard.string(forKey: key)
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        
        switch T.self {
        case is Bool.Type:
            UserDefaults.standard.setValue(value, forKey: key)
        case is Int.Type:
            UserDefaults.standard.setValue(value, forKey: key)
        case is Float.Type:
            UserDefaults.standard.setValue(value, forKey: key)
        case is Double.Type:
            UserDefaults.standard.setValue(value, forKey: key)
        case is String.Type:
            UserDefaults.standard.setValue(value, forKey: key)
            
        default:
            guard let data = try? JSONEncoder().encode(value),
                  let dataText = String(data: data, encoding: .utf8)
            else { return }
            UserDefaults.standard.setValue(dataText, forKey: key)
        }
    }
    
    public func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
