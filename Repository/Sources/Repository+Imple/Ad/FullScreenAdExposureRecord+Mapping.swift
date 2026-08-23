//
//  FullScreenAdExposureRecord+Mapping.swift
//  Repository
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


struct FullScreenAdExposureRecordMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case scopeType = "scope_type"
        case serviceIdentifier = "service_identifier"
        case lastExposeDate = "last_expose_date"
    }

    private enum ScopeType: String, Codable {
        case application
        case service
    }

    let record: FullScreenAdExposureRecord
    init(record: FullScreenAdExposureRecord) {
        self.record = record
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastExposeDate = try container.decode(Date.self, forKey: .lastExposeDate)
        let scope: FullScreenAdExposureRecord.Scope
        switch try container.decode(ScopeType.self, forKey: .scopeType) {
        case .application:
            scope = .application
        case .service:
            let identifier = try container.decode(String.self, forKey: .serviceIdentifier)
            scope = .service(identifier: identifier)
        }
        self.record = .init(scope: scope, lastExposeDate: lastExposeDate)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.record.lastExposeDate, forKey: .lastExposeDate)
        switch self.record.scope {
        case .application:
            try container.encode(ScopeType.application, forKey: .scopeType)
        case .service(let identifier):
            try container.encode(ScopeType.service, forKey: .scopeType)
            try container.encode(identifier, forKey: .serviceIdentifier)
        }
    }
}
