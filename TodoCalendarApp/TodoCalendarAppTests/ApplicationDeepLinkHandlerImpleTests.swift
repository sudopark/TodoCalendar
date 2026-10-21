//
//  ApplicationDeepLinkHandlerImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Domain
import Scenes
import Extensions
import TestDoubles

@testable import TodoCalendarApp


final class ApplicationDeepLinkHandlerImpleTests {

    private let spyRouter = SpyApplicationRouter()

    private func makeHandler() -> ApplicationDeepLinkHandlerImple {
        let handler = ApplicationDeepLinkHandlerImple()
        handler.appRouter = self.spyRouter
        return handler
    }
}


// MARK: - 업데이트 안내 팝업

extension ApplicationDeepLinkHandlerImpleTests {

    private func unknownHostLink() -> URL {
        return URL(string: "\(AppDeepLink.scheme)://unknown")!
    }

    @Test func handler_whenHandleUnknownHostLink_showUpdatePopupWithLocalizedCancelText() {
        // given
        let handler = self.makeHandler()

        // when
        _ = handler.handleLink(self.unknownHostLink())

        // then
        let dialog = self.spyRouter.didShowConfirmWith
        #expect(dialog?.cancelText == "common.cancel".localized())
        #expect(dialog?.cancelText != "common.cancel")
    }
}


private final class SpyApplicationRouter: BaseSpyRouter, ApplicationRouting, @unchecked Sendable {

    @MainActor
    func setupInitialScene(_ prepareResult: ApplicationPrepareResult) -> (any MainSceneInteractor)? {
        return nil
    }

    @MainActor
    func changeRootSceneAfter(signIn auth: Auth?) -> (any MainSceneInteractor)? {
        return nil
    }

    func showUpdatePopup(_ requirement: AppUpdateRequirement) { }
}
