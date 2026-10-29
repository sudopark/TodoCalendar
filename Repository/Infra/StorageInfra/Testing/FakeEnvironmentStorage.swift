//
//  FakeEnvironmentStorage.swift
//  StorageInfraTesting
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation
import StorageInfraInterface


public final class FakeEnvironmentStorage: EnvironmentStorage, @unchecked Sendable {
    
    private var storage: [String: String] = [:]
    
    public init() { }
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        guard let data = try? JSONEncoder().encode(value),
              let dataText = String(data: data, encoding: .utf8)
        else { return }
        self.storage[key] = dataText
    }
    
    public func remove(_ key: String) {
        self.storage.removeValue(forKey: key)
    }
    
    public func synchronize() { }
}
