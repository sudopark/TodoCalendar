//
//  DDayCandidate.swift
//  Domain
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 유저가 D-day 위젯 후보로 지정한 일정.
///
/// 자동 산출 후보군(오늘 ±365일·상한)이 못 담는 이벤트를 유저 지정으로 보완한다.
/// 반복 일정은 `turnKey`(`EventTime.customKey`)로 회차를 지목한다 — nil이면 원본 시각.
public struct DDayCandidate: Sendable, Hashable {

    public let scheduleId: String
    public var turnKey: String?

    public init(scheduleId: String, turnKey: String? = nil) {
        self.scheduleId = scheduleId
        self.turnKey = turnKey
    }
}
