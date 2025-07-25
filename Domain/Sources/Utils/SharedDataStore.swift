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
    case accountInfo
    case todos
    case schedules
    case tags
    case timeZone
    case currentCountry
    case availableCountries
    case holidays
    case firstWeekDay
    case offEventTagSet
    case calendarAppearance
    case defaultEventTagColor
    case eventSetting
    case foremostEventId
    case uncompletedTodos
    case externalCalendarAccounts
    case googleCalendarTags
    case googleCalendarEvents
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
    
    public func clearAll(filter: (String) -> Bool = { _ in true }) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.memorizedDataSubjects.forEach { key, subject in
            if filter(key) {
                subject.send(nil)
            }
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
