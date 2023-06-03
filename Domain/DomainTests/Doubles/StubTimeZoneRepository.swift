//
//  StubTimeZoneRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation
import Domain

final class StubTimezoneRepository: TimeZoneRepository, @unchecked Sendable {
    
    private var selectedTimeZone: TimeZone?
    func saveTimeZone(_ timeZone: TimeZone) {
        self.selectedTimeZone = timeZone
    }
    
    func loadUserSelectedTImeZone() -> TimeZone? {
        return self.selectedTimeZone
    }
}
