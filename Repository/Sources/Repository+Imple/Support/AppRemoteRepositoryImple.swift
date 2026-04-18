//
//  AppRemoteRepositoryImple.swift
//  Repository
//

import Foundation
import Domain

public final class AppRemoteRepositoryImple: AppRepository, @unchecked Sendable {

    private let remoteAPI: any RemoteAPI

    public init(remoteAPI: any RemoteAPI) {
        self.remoteAPI = remoteAPI
    }

    public func loadUpdateInfo() async throws -> AppUpdateInfo {
        let mapper: AppUpdateInfoMapper = try await self.remoteAPI.request(
            .get, AppEndpoints.updateInfo
        )
        return mapper.info
    }
}
