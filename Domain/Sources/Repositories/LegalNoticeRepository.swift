//
//  LegalNoticeRepository.swift
//  Domain
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public protocol LegalNoticeRepository: Sendable {

    func loadNoticeUpdates() async throws -> LegalNoticeUpdates
    func fetchConfirmedNoticeId(_ documentType: LegalDocumentType) -> String?
    func updateConfirmedNoticeId(_ id: String, for documentType: LegalDocumentType)
}
