//
//  FullScreenAdExposureRecord+Mapping.swift
//  AdDomain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import AdDomainInterface


struct FullScreenAdExposureRecordMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case lastExposeDate = "last_expose_date"
        case countOfDay = "count_of_day"
    }

    let record: FullScreenAdExposureRecord
    init(record: FullScreenAdExposureRecord) {
        self.record = record
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.record = .init(
            lastExposeDate: try container.decode(Date.self, forKey: .lastExposeDate),
            countOfDay: try container.decode(Int.self, forKey: .countOfDay)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.record.lastExposeDate, forKey: .lastExposeDate)
        try container.encode(self.record.countOfDay, forKey: .countOfDay)
    }
}
