//
//  ExternalCalendarAccountRemotePool.swift
//  Repository
//
//  Created by sudo.park on 3/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - ExternalCalendarRemoteFactory

public protocol ExternalCalendarRemoteFactory: Sendable {
    func make(serviceId: String, accountId: String) -> (any RemoteAPI)?
}


// MARK: - ExternalCalendarAccountRemotePool

public protocol ExternalCalendarAccountRemotePool: Sendable {

    func attach(listener: any AutenticatorTokenRefreshListener) async
    func setup(for serviceId: String, accountId: String, credential: APICredential) async
    func remove(for serviceId: String, accountId: String) async
    func remote(for serviceId: String, accountId: String) async throws -> any RemoteAPI
}


// MARK: - ExternalCalendarAccountRemotePoolImple

public actor ExternalCalendarAccountRemotePoolImple: ExternalCalendarAccountRemotePool {

    private let factory: any ExternalCalendarRemoteFactory
    private var remotePool: [String: any RemoteAPI] = [:]
    private weak var tokenRefreshListener: (any AutenticatorTokenRefreshListener)?

    public init(factory: any ExternalCalendarRemoteFactory) {
        self.factory = factory
    }

    private func poolKey(_ serviceId: String, _ accountId: String) -> String {
        return "\(serviceId)-\(accountId)"
    }
}


// MARK: - NopExternalCalendarAccountRemotePool (read-only contexts: widget, intent extension)

public struct NopExternalCalendarAccountRemotePool: ExternalCalendarAccountRemotePool {
    public init() { }
    public func attach(listener: any AutenticatorTokenRefreshListener) async { }
    public func setup(for serviceId: String, accountId: String, credential: APICredential) async { }
    public func remove(for serviceId: String, accountId: String) async { }
    public func remote(for serviceId: String, accountId: String) async throws -> any RemoteAPI {
        throw RuntimeError("no remote pool configured")
    }
}


extension ExternalCalendarAccountRemotePoolImple {

    public func attach(listener: any AutenticatorTokenRefreshListener) {
        self.tokenRefreshListener = listener
        remotePool.values.forEach { $0.attach(listener: listener) }
    }

    public func setup(for serviceId: String, accountId: String, credential: APICredential) {
        let key = poolKey(serviceId, accountId)
        if let existing = remotePool[key] {
            existing.setup(credential: credential)
        } else {
            guard let remote = factory.make(serviceId: serviceId, accountId: accountId) else { return }
            remote.setup(credential: credential)
            if let listener = tokenRefreshListener {
                remote.attach(listener: listener)
            }
            remotePool[key] = remote
        }
    }

    public func remove(for serviceId: String, accountId: String) {
        let key = poolKey(serviceId, accountId)
        remotePool[key]?.setup(credential: nil)
        remotePool.removeValue(forKey: key)
    }

    // TODO: [#504] GoogleCalendarRepositoryBuilder.build(for:)가 async throws로 변경되면
    // GoogleCalendarRepositoryBuilderImple에서 factory 직접 호출 대신 이 메서드로 교체 필요
    public func remote(for serviceId: String, accountId: String) throws -> any RemoteAPI {
        guard let remote = remotePool[poolKey(serviceId, accountId)] else {
            throw RuntimeError("remote not prepared: \(serviceId)-\(accountId)")
        }
        return remote
    }
}
