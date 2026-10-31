//
//  RemoteEnvironmentPathTests.swift
//  RemoteInfraTests
//
//  Created by sudo.park on 5/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface

@testable import RemoteInfra


// MARK: - 엔드포인트 호스트 종류별 경로 조립 검증

struct RemoteEnvironmentPathTests {

    private let env = RemoteEnvironment(
        calendarAPIHost: "https://api.example.com",
        csAPI: "https://cs.example.com",
        deviceId: "device_id",
        acceptLanguage: { "en" }
    )
}

extension RemoteEnvironmentPathTests {

    @Test func path_calendarAPIHost_joinsHostPathAndSubPath() {
        // when
        let path = self.env.path(DummyEndpoint.calendarAPI)
        // then
        #expect(path == "https://api.example.com/v2/dummy/some")
    }

    @Test func path_calendarAPIHostWithEmptySubPath_returnsPrefixOnly() {
        // when
        let path = self.env.path(DummyEndpoint.calendarAPIRoot)
        // then
        #expect(path == "https://api.example.com/v2/dummy")
    }

    @Test func path_customerServiceHost_usesCSAPI() {
        // when
        let path = self.env.path(DummyEndpoint.customerService)
        // then
        #expect(path == "https://cs.example.com/some")
    }

    @Test func path_externalHost_usesGivenBase() {
        // when
        let path = self.env.path(DummyEndpoint.external)
        // then
        #expect(path == "https://external.example.com/some")
    }
}
