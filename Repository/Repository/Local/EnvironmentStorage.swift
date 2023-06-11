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
        return UserDefaults.standard.string(forKey: key)
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {

        guard let data = try? JSONEncoder().encode(value),
              let dataText = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.setValue(dataText, forKey: key)
    }
    
    public func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
