//
//  PendingDoneTodoEventTableVersionSeeds.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Repository


// MARK: - 옛 버전 PendingDoneTodoEvent 시드

// 마이그레이션 전 물리 스키마를 세우는 테스트가 쓴다 —
// AppDataMigrationImpleTests 와 TodoLocalStorageImpleTests 둘이 소비한다

extension PendingDoneTodoEventTableV0.Entity {
    
    init(_ live: PendingDoneTodoEventTable.Entity) {
        self.init(
            uuid: live.uuid,
            name: live.name,
            createTimeStamp: live.createTimeStamp,
            eventTagId: live.eventTagId,
            repeatingStart: live.repeatingStart,
            repeatingOption: live.repeatingOption,
            repeatingEnd: live.repeatingEnd,
            notificationOptions: live.notificationOptions,
            timeType: live.timeType,
            timeLowerBound: live.timeLowerBound,
            timeUpperBound: live.timeUpperBound,
            secondsFromGMT: live.secondsFromGMT
        )
    }
}

extension PendingDoneTodoEventTableV1.Entity {
    
    init(_ live: PendingDoneTodoEventTable.Entity) {
        self.init(
            uuid: live.uuid,
            name: live.name,
            createTimeStamp: live.createTimeStamp,
            eventTagId: live.eventTagId,
            repeatingStart: live.repeatingStart,
            repeatingOption: live.repeatingOption,
            repeatingEnd: live.repeatingEnd,
            notificationOptions: live.notificationOptions,
            timeType: live.timeType,
            timeLowerBound: live.timeLowerBound,
            timeUpperBound: live.timeUpperBound,
            secondsFromGMT: live.secondsFromGMT,
            repeatingEndCount: live.repeatingEndCount
        )
    }
}
