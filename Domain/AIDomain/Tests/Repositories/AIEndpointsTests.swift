//
//  AIEndpointsTests.swift
//  AIDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import AIDomain



struct AIEndpointsTests {

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

extension AIEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: AIAPIEndpoints.command, path: "https://api.example.com/v1/ai/command", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.interpretCommand, path: "https://api.example.com/v1/ai/command/interpret", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.confirmCommand, path: "https://api.example.com/v1/ai/command/confirm", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.rejectCommand, path: "https://api.example.com/v1/ai/command/reject", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.cancelCommand, path: "https://api.example.com/v1/ai/command/cancel", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.job(id: "job-1"), path: "https://api.example.com/v1/ai/jobs/job-1", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AIAPIEndpoints.usage, path: "https://api.example.com/v1/ai/usage", authorization: .calendarAPI)
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
