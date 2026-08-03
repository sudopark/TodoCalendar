//
//  DDayCandidate+Mapping.swift
//  Repository
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct DDayCandidateMapper: Codable {

    let candidate: DDayCandidate

    init(candidate: DDayCandidate) {
        self.candidate = candidate
    }

    private enum CodingKeys: String, CodingKey {
        case scheduleId = "schedule_id"
        case turnKey = "turn_key"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.candidate = DDayCandidate(
            scheduleId: try container.decode(String.self, forKey: .scheduleId),
            turnKey: try container.decodeIfPresent(String.self, forKey: .turnKey)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.candidate.scheduleId, forKey: .scheduleId)
        try container.encodeIfPresent(self.candidate.turnKey, forKey: .turnKey)
    }
}
