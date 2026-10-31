//
//  BillingEndpointsTests.swift
//  BillingDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import BillingDomain



struct BillingEndpointsTests {

    private let env = RemoteEnvironment(
        calendarAPIHost: "https://api.example.com",
        csAPI: "https://cs.example.com",
        deviceId: "device_id",
        acceptLanguage: { "en" }
    )

    struct EndpointExpectation: Sendable {
        let endpoint: any Endpoint
        let path: String
        let authorization: EndpointAuthorization
    }
}

extension BillingEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: BillingAPIEndpoints.plans, path: "https://api.example.com/v1/billing/plans", authorization: .calendarAPI),
        EndpointExpectation(endpoint: BillingAPIEndpoints.topups, path: "https://api.example.com/v1/billing/topups", authorization: .calendarAPI),
        EndpointExpectation(endpoint: BillingAPIEndpoints.purchases, path: "https://api.example.com/v1/billing/purchases", authorization: .calendarAPI),
        EndpointExpectation(endpoint: BillingAPIEndpoints.transactions, path: "https://api.example.com/v1/billing/transactions", authorization: .calendarAPI),
        EndpointExpectation(endpoint: BillingAPIEndpoints.userPlan, path: "https://api.example.com/v1/billing/user-plan", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AppPolicyEndpoints.appPolicy, path: "https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/app-config/app-policy.json", authorization: .none)
    ])
    func endpoint_providesPathAndAuthorization(_ expectation: EndpointExpectation) {
        // given
        let endpoint = expectation.endpoint
        // when
        let path = self.env.path(endpoint)
        let authorization = endpoint.authorization
        // then
        #expect(path == expectation.path)
        #expect(authorization == expectation.authorization)
    }
}
