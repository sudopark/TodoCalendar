//
//  CalendarEndpointsTests.swift
//  CalendarDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import CalendarDomain



struct CalendarEndpointsTests {

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

extension CalendarEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: HolidayAPIEndpoints.holidays, path: "https://api.example.com/v2/holiday", authorization: .none),
        EndpointExpectation(endpoint: HolidayAPIEndpoints.supportCountry, path: "https://gist.githubusercontent.com/sudopark/31ca6b64687c1436ca7e5f705017071a/raw/251dd3885ab5b7ac112140e7b0e6a542fe2901f5/google_calendar_country", authorization: .none)
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
