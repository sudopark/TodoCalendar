//
//  AppColdLaunchHistory+Mapping.swift
//  Repository
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


struct AppColdLaunchHistoryMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case firstLaunchDate = "first_launch_date"
        case count
        case previousLaunchDate = "previous_launch_date"
        case lastLaunchDate = "last_launch_date"
    }

    let history: AppColdLaunchHistory
    init(history: AppColdLaunchHistory) {
        self.history = history
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.history = AppColdLaunchHistory()
            |> \.firstLaunchDate .~ (try container.decodeIfPresent(Date.self, forKey: .firstLaunchDate))
            |> \.count .~ (try container.decode(Int.self, forKey: .count))
            |> \.previousLaunchDate .~ (try container.decodeIfPresent(Date.self, forKey: .previousLaunchDate))
            |> \.lastLaunchDate .~ (try container.decodeIfPresent(Date.self, forKey: .lastLaunchDate))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.history.firstLaunchDate, forKey: .firstLaunchDate)
        try container.encode(self.history.count, forKey: .count)
        try container.encodeIfPresent(self.history.previousLaunchDate, forKey: .previousLaunchDate)
        try container.encodeIfPresent(self.history.lastLaunchDate, forKey: .lastLaunchDate)
    }
}
