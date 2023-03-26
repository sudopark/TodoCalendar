//
//  SharedDataStore.swift
//  Domain
//
//  Created by sudo.park on 2023/03/23.
//

import Foundation
import Combine
import Prelude
import Optics


public final class SharedDataStore: @unchecked Sendable {
    
    private let lock = NSRecursiveLock()
    private var memorizedDataSubjects: [String: CurrentValueSubject<Any?, Never>] = [:]
    
    public init() { }
    
    private func subject(for key: String) -> CurrentValueSubject<Any?, Never> {
        self.lock.lock(); defer { self.lock.unlock() }
        if let subject = self.memorizedDataSubjects[key] {
            return subject
        }
        let newSubject = CurrentValueSubject<Any?, Never>(nil)
        self.memorizedDataSubjects[key] = newSubject
        return newSubject
    }
    
    public func clearAll() {
        self.lock.lock(); defer { self.lock.unlock() }
        self.memorizedDataSubjects.values.forEach {
            $0.send(nil)
        }
    }
}


extension SharedDataStore {
    
    public func put<V>(_ type: V.Type, key: String, _ value: V) {
        self.subject(for: key)
            .send(value)
    }
    
    public func update<V>(_ type: V.Type, key: String, _ mutating: (V?) -> V) {
        let subject = self.subject(for: key)
        let newValue = subject.value as? V |> mutating
        subject.send(newValue)
    }
    
    public func delete(_ key: String) {
        self.subject(for: key).send(nil)
    }
    
    public func value<V>(_ type: V.Type, key: String) -> V? {
        return self.subject(for:key).value as? V
    }
    
    public func observe<V>(_ type: V.Type, key: String) -> AnyPublisher<V?, Never> {
        return self.subject(for: key)
            .map { $0 as? V }
            .eraseToAnyPublisher()
    }
}
