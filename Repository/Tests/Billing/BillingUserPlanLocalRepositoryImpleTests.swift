//
//  BillingUserPlanLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import SQLiteService
import UnitTestHelpKit

@testable import Repository


@Suite("BillingUserPlanLocalRepositoryImpleTests")
final class BillingUserPlanLocalRepositoryImpleTests: LocalTestable {

    var sqliteService: SQLiteService = .init()

    private func makeRepository() -> BillingUserPlanLocalRepositoryImple {
        return BillingUserPlanLocalRepositoryImple(sqliteService: self.sqliteService)
    }

    private func paidPlan() -> BillingUserPlan {
        return BillingUserPlan()
            |> \.planId .~ .standard
            |> \.topupRemaining .~ 3200
            |> \.scheduledChange .~ .init(
                planId: .free, effectiveAt: Date(timeIntervalSince1970: 1_787_000_000)
            )
    }

    // 앱이 모르는 플랜 id 가 실린 봉투는 우리 쪽 기록 경로로는 만들 수 없다 — 행에 직접 심어 덮는다
    private func seedRow(_ json: String) {
        _ = self.sqliteService.run { db in
            try db.insertOne(
                KeyValueTable.self,
                entity: KeyValueTable.Entity(.billingUserPlan, value: json),
                shouldReplace: true
            )
        }
    }
}


// MARK: - 저장값이 없을 때

extension BillingUserPlanLocalRepositoryImpleTests {

    @Test("저장된 플랜이 없으면 nil 을 준다")
    func repository_fetchPlan_whenEmpty_isNil() async throws {
        try await self.runTestWithOpenClose("billing_plan_1") {
            // given
            let repository = self.makeRepository()

            // when
            let plan = repository.fetchPlan()

            // then
            #expect(plan == nil)
        }
    }
}


// MARK: - 왕복

extension BillingUserPlanLocalRepositoryImpleTests {

    @Test("기록한 플랜을 읽으면 전 필드가 그대로 돌아온다")
    func repository_updateAndFetchPlan_roundTripsAllFields() async throws {
        try await self.runTestWithOpenClose("billing_plan_2") {
            // given
            let repository = self.makeRepository()

            // when
            repository.updatePlan(self.paidPlan())
            let plan = repository.fetchPlan()

            // then
            #expect(plan?.planId == .standard)
            #expect(plan?.topupRemaining == 3200)
            #expect(plan?.scheduledChange?.planId == .free)
            #expect(
                plan?.scheduledChange?.effectiveAt == Date(timeIntervalSince1970: 1_787_000_000)
            )
        }
    }

    @Test("다시 기록하면 앞 행을 덮는다")
    func repository_updatePlan_overwritesPrevious() async throws {
        try await self.runTestWithOpenClose("billing_plan_3") {
            // given
            let repository = self.makeRepository()
            repository.updatePlan(self.paidPlan())

            // when
            repository.updatePlan(BillingUserPlan() |> \.planId .~ .free)
            let plan = repository.fetchPlan()

            // then
            #expect(plan?.planId == .free)
            #expect(plan?.topupRemaining == nil)
            #expect(plan?.scheduledChange == nil)
        }
    }
}


// MARK: - 봉투 디코딩

extension BillingUserPlanLocalRepositoryImpleTests {

    @Test("봉투의 플랜 id 를 앱이 모르면 봉투는 살리고 그 id 만 떨군다")
    func repository_whenStoredPlanIdUnknown_keepsEnvelopeWithNilPlanId() async throws {
        try await self.runTestWithOpenClose("billing_plan_4") {
            // given
            let repository = self.makeRepository()
            self.seedRow(#"{ "plan_id": "enterprise", "topup_remaining": 7 }"#)

            // when
            let plan = repository.fetchPlan()

            // then
            #expect(plan != nil)
            #expect(plan?.planId == nil)
            #expect(plan?.topupRemaining == 7)
        }
    }

    @Test("예약의 플랜 id 를 앱이 모르면 그 예약만 떨구고 나머지는 살린다")
    func repository_whenScheduledChangeHasUnknownPlanId_dropsOnlyThatChange() async throws {
        try await self.runTestWithOpenClose("billing_plan_5") {
            // given
            let repository = self.makeRepository()
            self.seedRow(
                #"{ "plan_id": "standard", "topup_remaining": 7, "scheduled_change": { "plan_id": "enterprise", "effective_at": 808692800 } }"#
            )

            // when
            let plan = repository.fetchPlan()

            // then
            #expect(plan?.planId == .standard)
            #expect(plan?.topupRemaining == 7)
            #expect(plan?.scheduledChange == nil)
        }
    }

    @Test("예약에 발효 시각이 없으면 그 예약만 떨군다")
    func repository_whenScheduledChangeHasNoEffectiveAt_dropsOnlyThatChange() async throws {
        try await self.runTestWithOpenClose("billing_plan_6") {
            // given
            let repository = self.makeRepository()
            self.seedRow(#"{ "plan_id": "standard", "scheduled_change": { "plan_id": "free" } }"#)

            // when
            let plan = repository.fetchPlan()

            // then
            #expect(plan?.planId == .standard)
            #expect(plan?.scheduledChange == nil)
        }
    }

    @Test("행에 든 값이 플랜 봉투가 아니면 nil 을 준다")
    func repository_whenStoredTextIsNotEnvelope_isNil() async throws {
        try await self.runTestWithOpenClose("billing_plan_7") {
            // given
            let repository = self.makeRepository()
            self.seedRow("not a json")

            // when
            let plan = repository.fetchPlan()

            // then
            #expect(plan == nil)
        }
    }
}
