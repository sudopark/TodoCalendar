//
//  NotNeedBillingUsecaseTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit

@testable import Domain


final class NotNeedBillingUsecaseTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
}


extension NotNeedBillingUsecaseTests {

    @Test func usecase_whenCreated_seedFreePlan() {
        // given
        let sharedDataStore = SharedDataStore()

        // when
        _ = NotNeedBillingUsecase(sharedDataStore: sharedDataStore)

        // then
        let plan = sharedDataStore.value(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue)
        #expect(plan?.planId == .free)
    }

    @Test func usecase_whenCreated_confirmationBecomeFreeConfirmed() async throws {
        // given
        let sharedDataStore = SharedDataStore()
        let expect = expectConfirm("미로그인 세션 생성 즉시 free 확정")

        // when
        _ = NotNeedBillingUsecase(sharedDataStore: sharedDataStore)
        let confirmationUsecase = BillingUserPlanConfirmationUsecaseImple(sharedDataStore: sharedDataStore)
        let confirmation = try await self.firstOutput(expect, for: confirmationUsecase.userPlanConfirmation)

        // then
        #expect(confirmation?.isFreeConfirmed() == true)
    }
}
