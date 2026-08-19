//
//  LiveActivityToggleViewModelImpleTests.swift
//  ScenesTests
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions
import TestDoubles

@testable import Scenes


struct LiveActivityToggleViewModelImpleTests {

    private let spyRouter = BaseSpyRouter()
    private let stubUsecase = StubEventLiveActivityUsecase()

    private func makeViewModel() -> LiveActivityToggleViewModelImple {
        let viewModel = LiveActivityToggleViewModelImple(
            eventLiveActivityUsecase: self.stubUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    @Test func viewModel_whenRegisterSucceed_showToastToCheckLockScreen() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.startOrStopLiveActivity(.todo(id: "todo-1"), isCurrentlyRegistered: false)
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.stubUsecase.didStartTarget == .todo(id: "todo-1"))
        #expect(
            self.spyRouter.didShowToastWithMessage
                == "calendar::event::more_action:live_activity:register:success".localized()
        )
    }

    @Test func viewModel_whenRegisterFail_notShowToastAndGuideUnavailable() async throws {
        // given
        self.stubUsecase.stubStartError = EventLiveActivityStartFailReason.alreadyPassed
        let viewModel = self.makeViewModel()

        // when
        viewModel.startOrStopLiveActivity(.todo(id: "todo-1"), isCurrentlyRegistered: false)
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowToastWithMessage == nil)
        #expect(
            self.spyRouter.didShowConfirmWith?.message
                == "calendar::event::more_action:live_activity:unavail::already_passed".localized()
        )
    }

    @Test func viewModel_whenUnregister_notShowToast() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.startOrStopLiveActivity(.todo(id: "todo-1"), isCurrentlyRegistered: true)
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.stubUsecase.didStopActivity == true)
        #expect(self.spyRouter.didShowToastWithMessage == nil)
    }
}
