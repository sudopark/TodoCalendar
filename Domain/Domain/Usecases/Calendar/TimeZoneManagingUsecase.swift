//
//  TimeZoneUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/03.
//

import Foundation
import Combine


public protocol TimeZoneManagingUsecase {
    
    func loadAllTimeZones() -> [TimeZone]
    
    func selectTimeZone(_ timeZone: TimeZone)
    
    var currentTimeZone: AnyPublisher<TimeZone, Never> { get }
}


public final class TimeZoneManagingUsecaseImple: TimeZoneManagingUsecase {
    
    private let timeZoneRepository: TimeZoneRepository
    private let shareDataStore: SharedDataStore
    
    public init(
        timeZoneRepository: TimeZoneRepository,
        shareDataStore: SharedDataStore
    ) {
        self.timeZoneRepository = timeZoneRepository
        self.shareDataStore = shareDataStore
    }
}

extension TimeZoneManagingUsecaseImple {
    
    public func loadAllTimeZones() -> [TimeZone] {
        let timeZoneIdentifiers = TimeZone.knownTimeZoneIdentifiers
        return timeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }
    }
    
    public func selectTimeZone(_ timeZone: TimeZone) {
        self.timeZoneRepository.saveTimeZone(timeZone)
        let shareKey = ShareDataKeys.timeZone.rawValue
        self.shareDataStore.update(TimeZone.self, key: shareKey) { _ in timeZone }
    }
}

extension TimeZoneManagingUsecaseImple {
    
    public var currentTimeZone: AnyPublisher<TimeZone, Never> {
        let shareKey = ShareDataKeys.timeZone.rawValue
        
        let setupSavedTimeZone: (Subscription) -> Void = { [weak self] _ in
            guard let savedTimezone = self?.timeZoneRepository.loadUserSelectedTImeZone()
            else { return }
            self?.shareDataStore.update(TimeZone.self, key: shareKey) { _ in savedTimezone }
        }
        
        return self.shareDataStore
            .observe(TimeZone.self, key: shareKey)
            .map { $0 ?? TimeZone.current }
            .handleEvents(receiveSubscription: setupSavedTimeZone)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
