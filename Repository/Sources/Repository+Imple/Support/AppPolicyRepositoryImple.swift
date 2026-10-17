//
//  AppPolicyRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class AppPolicyRepositoryImple: AppPolicyRepository, Sendable {

    private let remoteAPI: any RemoteAPI
    private let environmentStorage: any EnvironmentStorage

    public init(
        remoteAPI: any RemoteAPI,
        environmentStorage: any EnvironmentStorage
    ) {
        self.remoteAPI = remoteAPI
        self.environmentStorage = environmentStorage
    }

    private var policyKey: String { EnvironmentKeys.appPolicy.rawValue }
}


extension AppPolicyRepositoryImple {

    public func loadPolicy() -> AppPolicy? {
        let cached: AppPolicyMapper? = self.environmentStorage.load(self.policyKey)
        return cached?.policy
    }

    public func refreshPolicy() async throws {
        let mapper: AppPolicyMapper = try await self.remoteAPI.request(
            .get, AppEndpoints.appPolicy
        )
        self.environmentStorage.update(self.policyKey, mapper)
    }
}
