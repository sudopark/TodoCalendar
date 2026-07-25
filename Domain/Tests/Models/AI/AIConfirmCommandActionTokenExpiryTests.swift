//
//  AIConfirmCommandActionTokenExpiryTests.swift
//  Domain
//
//  Created by sudo.park on 7/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


final class AIConfirmCommandActionTokenExpiryTests {

    private func makeAction(token: String?) -> AIConfirmCommandAction {
        return AIConfirmCommandAction()
            |> \.confirmToken .~ token
    }

    // base64url(패딩 제거) 인코딩으로 JWT 형태 토큰 구성
    private func makeToken(payload: [String: Any]) -> String {
        let encode: ([String: Any]) -> String = { dict in
            let data = try! JSONSerialization.data(withJSONObject: dict)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = encode(["alg": "HS256", "typ": "JWT"])
        return "\(header).\(encode(payload)).dummy-signature"
    }
}


// MARK: - exp 파싱

extension AIConfirmCommandActionTokenExpiryTests {

    @Test func action_tokenHasExp_parsesExpireTime() {
        // given
        let exp: TimeInterval = 1_800_000_000
        let action = self.makeAction(
            token: self.makeToken(payload: ["jobId": "job-1", "exp": exp])
        )
        // when
        let expireTime = action.tokenExpireTime
        // then
        #expect(expireTime == Date(timeIntervalSince1970: exp))
    }

    @Test func action_tokenWithoutExp_returnsNil() {
        // given
        let action = self.makeAction(token: self.makeToken(payload: ["jobId": "job-1"]))
        // when + then
        #expect(action.tokenExpireTime == nil)
    }

    @Test(arguments: [nil, "not-a-jwt", "only.two", "a.!!invalid-base64!!.c"])
    func action_tokenNotDecodable_returnsNil(_ token: String?) {
        // given
        let action = self.makeAction(token: token)
        // when + then
        #expect(action.tokenExpireTime == nil)
    }
}
