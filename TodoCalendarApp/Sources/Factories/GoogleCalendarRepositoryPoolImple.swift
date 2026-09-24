//
//  GoogleCalendarRepositoryPoolImple.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository

// MARK: - GoogleCalendarRepositoryPoolImple

final class GoogleCalendarRepositoryPoolImple: GoogleCalendarRepositoryPool, @unchecked Sendable {

    private let accountRemotePool: any ExternalCalendarAccountRemotePool
    private let connectionPool: any ExternalCalendarDBConnectionPool
    private var pool: [String: any GoogleCalendarRepository] = [:]
    private let lock = NSLock()

    init(accountRemotePool: any ExternalCalendarAccountRemotePool, connectionPool: any ExternalCalendarDBConnectionPool) {
        self.accountRemotePool = accountRemotePool
        self.connectionPool = connectionPool
    }

    func repository(for accountId: String) -> any GoogleCalendarRepository {
        lock.lock(); defer { lock.unlock() }
        if let cached = pool[accountId] {
            return cached
        }
        guard let remote = try? accountRemotePool.remote(for: GoogleCalendarService.id, accountId: accountId) else {
            preconditionFailure("remote not prepared for accountId: \(accountId)")
        }
        let cacheStorage = GoogleCalendarLocalStorageImple(connectionPool: self.connectionPool)
        let repository = GoogleCalendarRepositoryImple(
            remote: remote,
            cacheStorage: cacheStorage,
            accountId: accountId
        )
        pool[accountId] = repository
        return repository
    }

    func removeRepository(for accountId: String) {
        lock.lock(); defer { lock.unlock() }
        pool[accountId] = nil
    }
}
