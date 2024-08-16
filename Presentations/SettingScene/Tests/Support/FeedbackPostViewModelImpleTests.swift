//
//  FeedbackPostViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 8/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class FeedbackPostViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel() -> FeedbackPostViewModelImple {
        let usecase = PrivateStubUsecase()
        let viewModel = FeedbackPostViewModelImple(feedbackUsecase: usecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}
 
extension FeedbackPostViewModelImpleTests {
 
    func testViewModel_whenEnterValidContactAndMessage_updateIsPostable() {
        // given
        let expect = expectation(description: "연락처와 메세지 정보 입력여부에 따라 등록 가능여부 업데이트")
        expect.expectedFulfillmentCount = 6
        let viewModel = self.makeViewModel()
        
        // when
        let isPostables = self.waitOutputs(expect, for: viewModel.isPostable) {
            viewModel.enter(contact: "contact")
            viewModel.enter(message: "message")
            viewModel.enter(contact: "")
            viewModel.enter(contact: "contact")
            viewModel.enter(message: "")
            viewModel.enter(message: "some")
        }
        
        // then
        XCTAssertEqual(isPostables, [false, true, false, true, false, true])
    }
    
    func testViewModel_postFeedback_andCloseWithAlert() {
        // given
        let expect = expectation(description: "피드백 등록 이후 알림노출하고 화면 닫음")
        let viewModel = self.makeViewModel()
        self.spyRouter.didShowConfirmWithCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.enter(contact: "contact")
        viewModel.enter(message: "message")
        viewModel.post()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    
    func testViewModel_whenPostFeedback_updateIsPosting() {
        // given
        let expect = expectation(description: "피드백 등록중에는 등록중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isPostings = self.waitOutputs(expect, for: viewModel.isPosting) {
            viewModel.enter(contact: "contact")
            viewModel.enter(message: "message")
            viewModel.post()
        }
        
        // then
        XCTAssertEqual(isPostings, [false, true, false])
    }
}


private class SpyRouter: BaseSpyRouter, FeedbackPostRouting, @unchecked Sendable { }
private class PrivateStubUsecase: FeedbackUsecase, @unchecked Sendable {
    
    func postFeedback(_ message: FeedbackPostMessage) async throws { }
}
