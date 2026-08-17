//
//  EventCountdownActivityAttributes.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import ActivityKit


struct EventCountdownActivityAttributes: ActivityAttributes {

    typealias ContentState = State

    let target: LiveActivityEventTarget

    struct State: Codable, Hashable, Sendable {
        var eventName: String
        var eventTimeText: String
        var tagColorHex: String
        var eventDate: Date
        /// 남은시간 링의 분모 시작점 — 등록 시점을 담는다. 렌더 시점을 쓰면 갱신마다 링이 다시 꽉 찬다.
        var startDate: Date
        var placeName: String? = nil
        var memo: String? = nil
    }
}
