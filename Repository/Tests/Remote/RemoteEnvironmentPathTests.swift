//
//  RemoteEnvironmentPathTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 5/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain

@testable import Repository


// MARK: - calendarAPIHost 기반 엔드포인트 v2 prefix 매핑 검증

struct RemoteEnvironmentPathTests {

    private let env = RemoteEnvironment(
        calendarAPIHost: "https://api.example.com",
        csAPI: "https://cs.example.com",
        deviceId: "device_id",
        acceptLanguage: { "en" }
    )
}

extension RemoteEnvironmentPathTests {

    @Test func path_holidaysEndpoint_returnsV2HolidayURL() {
        // when
        let path = self.env.path(HolidayAPIEndpoints.holidays)
        // then
        #expect(path == "https://api.example.com/v2/holiday")
    }

    @Test func path_accountInfoEndpoint_returnsV2AccountsInfoURL() {
        // when
        let path = self.env.path(AccountAPIEndpoints.info)
        // then
        #expect(path == "https://api.example.com/v2/accounts/info")
    }

    @Test func path_foremostEventEndpoint_returnsV2ForemostEventURL() {
        // when
        let path = self.env.path(ForemostEventEndpoints.event)
        // then
        #expect(path == "https://api.example.com/v2/foremost/event")
    }

    @Test func path_eventDetailEndpoint_returnsV2EventDetailsURL() {
        // when
        let path = self.env.path(EventDetailEndpoints.detail(eventId: "id"))
        // then
        #expect(path == "https://api.example.com/v2/event_details/id")
    }

    @Test func path_appSettingDefaultColorEndpoint_returnsV2SettingURL() {
        // when
        let path = self.env.path(AppSettingEndpoints.defaultEventTagColor)
        // then
        #expect(path == "https://api.example.com/v2/setting/event/tag/default/color")
    }

    @Test func path_eventSyncCheckEndpoint_returnsV2SyncCheckURL() {
        // when
        let path = self.env.path(EventSyncEndPoints.check)
        // then
        #expect(path == "https://api.example.com/v2/sync/check")
    }
}
