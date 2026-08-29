//
//  LegalNotice.swift
//  Domain
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum LegalDocumentType: String, Sendable, CaseIterable {
    case terms
    case privacy

    public var linkPath: String {
        switch self {
        case .terms: return LegalLink.termsPath
        case .privacy: return LegalLink.privacyPolicyPath
        }
    }
}

public struct LegalNoticeUpdateInfo: Sendable, Equatable {

    public let id: String
    public let documentType: LegalDocumentType
    public let effectiveDate: Date

    public init(id: String, documentType: LegalDocumentType, effectiveDate: Date) {
        self.id = id
        self.documentType = documentType
        self.effectiveDate = effectiveDate
    }
}

public typealias LegalNoticeUpdates = [LegalDocumentType: LegalNoticeUpdateInfo]
