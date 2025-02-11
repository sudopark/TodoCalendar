//
//  GoogleCalendarUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - GoogleCalendarViewAppearanceStore

public protocol GoogleCalendarViewAppearanceStore: Sendable {
    
    func apply(colors: GoogleCalendarColors)
    func clearGoogleCalendarColors()
}


// MARK: - GoogleCalendarUsecase

public protocol GoogleCalendarUsecase: Sendable {
    
    func prepare()
}


public final class GoogleCalendarUsecaseImple: GoogleCalendarUsecase, @unchecked Sendable {
    
    private let googleService: GoogleCalendarService
    private let repository: any GoogleCalendarRepository
    private let appearanceStore: any GoogleCalendarViewAppearanceStore
    private let sharedDataStore: SharedDataStore
    
    public init(
        googleService: GoogleCalendarService,
        repository: any GoogleCalendarRepository,
        appearanceStore: any GoogleCalendarViewAppearanceStore,
        sharedDataStore: SharedDataStore
    ) {
        self.googleService = googleService
        self.repository = repository
        self.appearanceStore = appearanceStore
        self.sharedDataStore = sharedDataStore
    }
    
    private var cancelBag: Set<AnyCancellable> = []
}


extension GoogleCalendarUsecaseImple {
    
    public func prepare() {
        
        let serviceId = self.googleService.identifier
        let hasAccount = self.sharedDataStore
            .observe(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue
            )
            .map { $0?[serviceId] != nil }
        
        hasAccount
            .removeDuplicates()
            .sink(receiveValue: { [weak self] has in
                if has {
                    self?.refreshColors()
                } else {
                    self?.appearanceStore.clearGoogleCalendarColors()
                }
            })
            .store(in: &self.cancelBag)
    }
    
    private func refreshColors() {
        self.repository.loadColors()
            .sink(receiveValue: { [weak self] colors in
                self?.appearanceStore.apply(colors: colors)
            })
            .store(in: &self.cancelBag)
    }
}
