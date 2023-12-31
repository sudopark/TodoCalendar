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

public enum ShareDataKeys: String {
    case todos
    case doneTodos
    case schedules
    case tags
    case timeZone
    case currentCountry
    case availableCountries
    case holidays
    case firstWeekDay
    case offEventTagSet
    case uiSetting
    case eventSetting
    case latestUsedEventTag
}


public final class SharedDataStore: @unchecked Sendable {
    
    private let lock = NSRecursiveLock()
    private var memorizedDataSubjects: [String: CurrentValueSubject<Any?, Never>] = [:]
    private let serialEventQeueu: DispatchQueue?
    
    public init(
        serialEventQeueu: DispatchQueue? = DispatchQueue(label: "serial-sharedDataStore-event")
    ) {
        self.serialEventQeueu = serialEventQeueu
    }
    
    private func subject(for key: String) -> CurrentValueSubject<Any?, Never> {
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
        self.lock.lock(); defer { self.lock.unlock() }
        self.subject(for: key)
            .send(value)
    }
    
    public func update<V>(_ type: V.Type, key: String, _ mutating: (V?) -> V) {
        self.lock.lock(); defer { self.lock.unlock() }
        let subject = self.subject(for: key)
        let newValue = subject.value as? V |> mutating
        subject.send(newValue)
    }
    
    public func delete(_ key: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.subject(for: key).send(nil)
    }
    
    public func value<V>(_ type: V.Type, key: String) -> V? {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.subject(for:key).value as? V
    }
    
    public func observe<V>(_ type: V.Type, key: String) -> AnyPublisher<V?, Never> {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.subject(for: key)
            .map { $0 as? V }
            .receiveOnIfPossible(self.serialEventQeueu)
    }
}
