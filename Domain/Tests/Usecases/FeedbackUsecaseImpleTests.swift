//
//  FeedbackUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class FeedbackUsecaseImpleTests: BaseTestCase {
    
    private var spyRepository: StubFeedbackRepository!
    override func setUpWithError() throws {
        self.spyRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRepository = nil
    }
    
    private func makeUsecase(
        withAccount: Bool = false
    ) -> FeedbackUsecaseImple {
        let deviceInfoService = StubDeviceInfoFetchService()
        let account = withAccount ? AccountInfo("some") : nil
        let stubAccountUsecase = StubAccountUsecase(account)
        return FeedbackUsecaseImple(
            accountUsecase: stubAccountUsecase,
            feedbackRepository: self.spyRepository,
            deviceInfoFetchService: deviceInfoService
        )
    }
}

extension FeedbackUsecaseImpleTests {
    
    var dummyMessage: FeedbackPostMessage {
        return .init(contactEmail: "contact", message: "message")
    }
    
    func testUsecase_postFeedbackMessage() async throws {
        // given
        let usecase = self.makeUsecase()
        // when + then
        try await usecase.postFeedback(self.dummyMessage)
    }
    
    func testUsecase_postFeedbackMessageWithDeviceInfo() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        try await usecase.postFeedback(self.dummyMessage)
        
        // then
        XCTAssertEqual(self.spyRepository.didPostFeedbackWith?.osVersion, "os")
        XCTAssertEqual(self.spyRepository.didPostFeedbackWith?.appVersion, "app")
        XCTAssertEqual(self.spyRepository.didPostFeedbackWith?.deviceModel, "model")
    }
    
    func testUsecase_whenLogin_postFeedbackMessageWithUserId() async throws {
        // given
        func parameterizeTest(hasAccount: Bool) async throws {
            // given
            let usecase = self.makeUsecase(withAccount: hasAccount)
            
            // when
            try await usecase.postFeedback(self.dummyMessage)
            
            // then
            XCTAssertEqual(self.spyRepository.didPostFeedbackWith?.userId != nil, hasAccount)
        }
        
        // when + then
        try await parameterizeTest(hasAccount: false)
        try await parameterizeTest(hasAccount: true)
    }
}

private class StubFeedbackRepository: FeedbackRepository, @unchecked Sendable {
    
    var didPostFeedbackWith: FeedbackMakeParams?
    func postFeedback(_ params: FeedbackMakeParams) async throws {
        self.didPostFeedbackWith = params
    }
}
