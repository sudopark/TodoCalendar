//
//  SupportEndpointsTests.swift
//  SupportDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import SupportDomain



struct SupportEndpointsTests {

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

extension SupportEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: FeedbackEndpoints.post, path: "https://cs.example.com", authorization: .none),
        EndpointExpectation(endpoint: AppEndpoints.updateInfo, path: "https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/app-config/update-info.json", authorization: .none),
        EndpointExpectation(endpoint: AppEndpoints.legalNotice, path: "https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/app-config/legal-notice.json", authorization: .none)
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
