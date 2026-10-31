//
//  SettingEndpointsTests.swift
//  SettingDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import SettingDomain



struct SettingEndpointsTests {

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

extension SettingEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: AppSettingEndpoints.defaultEventTagColor, path: "https://api.example.com/v2/setting/event/tag/default/color", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AppSettingEndpoints.colorThemes, path: "https://api.example.com/v2/setting/color_themes", authorization: .calendarAPI),
        EndpointExpectation(endpoint: AppSettingEndpoints.colorTheme(uuid: "theme-1"), path: "https://api.example.com/v2/setting/color_themes/theme-1", authorization: .calendarAPI)
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
