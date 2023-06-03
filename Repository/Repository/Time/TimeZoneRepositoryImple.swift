//
//  TimeZoneRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/06/04.
//

import Foundation
import Domain


public final class TimeZoneRepositoryImple: TimeZoneRepository, Sendable {
    
    private let environmentStorage: EnvironmentStorage
    
    public init(environmentStorage: EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }
    
    private var timeZoneKey: String { "user_timeZone" }
}

extension TimeZoneRepositoryImple {
    
    public func loadUserSelectedTImeZone() -> TimeZone? {
        guard let abbreviation: String = self.environmentStorage.load(self.timeZoneKey)
        else { return nil }
        return TimeZone(abbreviation: abbreviation)
    }
    
    public func saveTimeZone(_ timeZone: TimeZone) {
        let abbreviation = timeZone.addreviationKey
        self.environmentStorage.update(self.timeZoneKey, abbreviation)
    }
}
