//
//  LegalNoticeRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class LegalNoticeRepositoryImple: LegalNoticeRepository, @unchecked Sendable {

    private let remoteAPI: any RemoteAPI
    private let environmentStorage: any EnvironmentStorage

    public init(remoteAPI: any RemoteAPI, environmentStorage: any EnvironmentStorage) {
        self.remoteAPI = remoteAPI
        self.environmentStorage = environmentStorage
    }

    private func confirmedNoticeIdKey(for documentType: LegalDocumentType) -> String {
        return "confirmed_legal_notice_id_\(documentType.rawValue)"
    }

    public func loadNoticeUpdates() async throws -> LegalNoticeUpdates {
        let mapper: LegalNoticeMapper = try await self.remoteAPI.request(
            .get, AppEndpoints.legalNotice
        )
        return mapper.updates
    }

    public func fetchConfirmedNoticeId(_ documentType: LegalDocumentType) -> String? {
        return self.environmentStorage.load(self.confirmedNoticeIdKey(for: documentType))
    }

    public func updateConfirmedNoticeId(_ id: String, for documentType: LegalDocumentType) {
        self.environmentStorage.update(self.confirmedNoticeIdKey(for: documentType), id)
    }
}
