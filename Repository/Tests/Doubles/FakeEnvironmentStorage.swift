//
//  FakeEnvironmentStorage.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation

@testable import Repository

final class FakeEnvironmentStorage: EnvironmentStorage, @unchecked Sendable {
    
    private var storage: [String: String] = [:]
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        guard let data = try? JSONEncoder().encode(value),
              let dataText = String(data: data, encoding: .utf8)
        else { return }
        self.storage[key] = dataText
    }
    
    func remove(_ key: String) {
        self.storage.removeValue(forKey: key)
    }
    
    func synchronize() { }
}
