//
//  FakeEnvironmentStorage.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation

@testable import Repository

final class FakeEnvironmentStorage: EnvironmentStorage, @unchecked Sendable {
    
    private var storage: [String: Any] = [:]
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value
    }
    
    func remove(_ key: String) {
        self.storage.removeValue(forKey: key)
    }
}
