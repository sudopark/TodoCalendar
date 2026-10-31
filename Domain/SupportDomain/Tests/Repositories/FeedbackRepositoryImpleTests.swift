//
//  FeedbackRepositoryImpleTests.swift
//  SupportDomainTests
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import RemoteInfraInterface
import RemoteInfraTesting
@testable import SupportDomain
@testable import SupportDomainInterface



class FeedbackRepositoryImpleTests: BaseTestCase {
    
    private var stubRemote: StubRemoteAPI!
    
    override func setUpWithError() throws {
        self.stubRemote = .init(responses: self.responses)
    }
    
    private func makeRepository() -> FeedbackRepositoryImple {
        return FeedbackRepositoryImple(remote: self.stubRemote)
    }
}

extension FeedbackRepositoryImpleTests {
    
    private var dummyMakeParams: FeedbackMakeParams {
        return .init("contact", "message")
            |> \.userId .~ "user_id"
            |> \.osVersion .~ "os"
            |> \.appVersion .~ "app_version"
            |> \.deviceModel .~ "model"
            |> \.isIOSAppOnMac .~ true
    }
    
    func testRepository_postFeedback() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        try await repository.postFeedback(params)
        
        // then
        let didRequestedParams = self.stubRemote.didRequestedParams ?? [:]
        let attach = didRequestedParams["attachments"] as? [[String: Any]]
        let firstAttach = attach?.first ?? [:]
        XCTAssertEqual(firstAttach["fallback"] as? String, "incomming cs from: <contact>")
        XCTAssertEqual(firstAttach["pretext"] as? String, "incomming cs from: <contact>")
        XCTAssertEqual(firstAttach["color"] as? String, "good")
        let fields = firstAttach["fields"] as? [[String: Any]] ?? []
        let fieldTitles = fields.map { fs in fs["title"] as? String }
        XCTAssertEqual(fieldTitles, [
            "Message", "user id", "os version", "app version", "device model", "is ios app on Mac?"
        ])
    }
}

private extension FeedbackRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .post,
                endpoint: FeedbackEndpoints.post,
                resultJsonString: .success("ok"))
        ]
    }
}
