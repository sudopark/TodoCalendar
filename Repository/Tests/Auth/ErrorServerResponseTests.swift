//
//  ErrorServerResponseTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Alamofire
import Prelude
import Optics
import Domain
import Extensions

@testable import Repository

struct ErrorServerResponseTests {

    struct ServerResponseCase: @unchecked Sendable {
        let label: String
        let error: any Error
        let isNotReceived: Bool
    }

    @Test("에러가 서버 응답을 받지 못한 상황을 나타내는지 판정", arguments: [
        ServerResponseCase(
            label: "URLError(.timedOut)",
            error: URLError(.timedOut),
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "URLError(.notConnectedToInternet)",
            error: URLError(.notConnectedToInternet),
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "URLError(.networkConnectionLost)",
            error: URLError(.networkConnectionLost),
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "AFError.sessionTaskFailed(URLError(.timedOut))",
            error: AFError.sessionTaskFailed(error: URLError(.timedOut)),
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "AFError.explicitlyCancelled",
            error: AFError.explicitlyCancelled,
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "AFError.responseValidationFailed(.unacceptableStatusCode(400))",
            error: AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 400)),
            isNotReceived: false
        ),
        ServerResponseCase(
            label: "ServerErrorModel(statusCode: 400)",
            error: ServerErrorModel() |> \.statusCode .~ 400,
            isNotReceived: false
        ),
        ServerResponseCase(
            label: "ServerErrorModel(code: .cancelled, statusCode: nil)",
            error: ServerErrorModel() |> \.code .~ .cancelled,
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "ServerErrorModel(code: .cancelled, statusCode: 400)",
            error: ServerErrorModel() |> \.code .~ .cancelled |> \.statusCode .~ 400,
            isNotReceived: false
        ),
        ServerResponseCase(
            label: "ServerErrorModel(code: nil, statusCode: nil)",
            error: ServerErrorModel(),
            isNotReceived: false
        ),
        ServerResponseCase(
            label: "NSError(FIRAuthErrorDomain, 17020, underlying: URLError(.timedOut))",
            error: NSError(
                domain: "FIRAuthErrorDomain",
                code: 17020,
                userInfo: [NSUnderlyingErrorKey: URLError(.timedOut)]
            ),
            isNotReceived: true
        ),
        ServerResponseCase(
            label: "NSError(FIRAuthErrorDomain, 17011, user not found)",
            error: NSError(domain: "FIRAuthErrorDomain", code: 17011, userInfo: [:]),
            isNotReceived: false
        ),
        ServerResponseCase(
            label: "RuntimeError(\"not current user\")",
            error: RuntimeError("not current user"),
            isNotReceived: false
        )
    ])
    func error_checkServerResponseNotReceived(_ testCase: ServerResponseCase) {
        // given
        let error = testCase.error

        // when
        let isNotReceived = error.isServerResponseNotReceived

        // then
        #expect(isNotReceived == testCase.isNotReceived, "\(testCase.label)")
    }
}
