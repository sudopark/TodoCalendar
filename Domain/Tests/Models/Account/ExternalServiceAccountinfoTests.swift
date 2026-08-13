//
//  ExternalServiceAccountinfoTests.swift
//  Domain
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics

@testable import Domain

struct ExternalServiceAccountinfoTests {

    private func makeAccount(_ scopes: [String]?) -> ExternalServiceAccountinfo {
        return ExternalServiceAccountinfo(GoogleCalendarService.id, email: "some@gmail.com")
            |> \.grantedScopes .~ scopes
    }
}

// MARK: - 쓰기 가능 판정

extension ExternalServiceAccountinfoTests {

    @Test("허용 scope 기록이 없는 기존 계정은 쓰기 불가")
    func account_whenGrantedScopesIsNil_cannotWrite() {
        // given
        let account = self.makeAccount(nil)
        // when
        let canWrite = account.canWriteGoogleCalendar
        // then
        #expect(canWrite == false)
    }

    @Test("readonly 만 허용받은 계정은 쓰기 불가")
    func account_whenOnlyReadOnlyGranted_cannotWrite() {
        // given
        let account = self.makeAccount(["https://www.googleapis.com/auth/calendar.readonly"])
        // when
        let canWrite = account.canWriteGoogleCalendar
        // then
        #expect(canWrite == false)
    }

    @Test("calendar scope 를 허용받은 계정은 쓰기 가능")
    func account_whenCalendarScopeGranted_canWrite() {
        // given
        let account = self.makeAccount([
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/userinfo.email"
        ])
        // when
        let canWrite = account.canWriteGoogleCalendar
        // then
        #expect(canWrite == true)
    }
}
