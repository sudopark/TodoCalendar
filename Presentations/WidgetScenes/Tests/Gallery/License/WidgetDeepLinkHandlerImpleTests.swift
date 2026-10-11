//
//  WidgetDeepLinkHandlerImpleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import WidgetScenes


final class SpyWidgetLicenseGuideHostRouter: SpyWidgetStyleLicenseGuideRouter, WidgetLicenseGuideHostRouting, @unchecked Sendable {

    var hasTopScene: Bool = true
    private(set) var didAskTopScene: Bool = false
    func attachTopScene() -> Bool {
        self.didAskTopScene = true
        return self.hasTopScene
    }
}


final class WidgetDeepLinkHandlerImpleTests: AsyncEffectWaitable {

    private func makeHandler(
        canCreate: Bool, hasTopScene: Bool = true
    ) -> (WidgetDeepLinkHandlerImple, SpyWidgetLicenseGuideHostRouter) {
        let gate = StubWidgetStylePaidFeatureGateUsecase()
        gate.canCreateWithoutAd = canCreate
        let router = SpyWidgetLicenseGuideHostRouter()
        router.hasTopScene = hasTopScene
        let handler = WidgetDeepLinkHandlerImple(paidFeatureGateUsecase: gate, router: router)
        return (handler, router)
    }

    private func link(_ path: String) throws -> PendingDeepLink {
        let url = try #require(URL(string: "tc.app://widget/\(path)"))
        return try #require(PendingDeepLink(url))
    }

    @Test("권한 없이 잠김 링크로 들어오면 최상단 화면에 광고·플랜 안내를 띄운다")
    func handler_licenseLinkWithoutPermission_showsGuide() async throws {
        // given
        let (handler, router) = self.makeHandler(canCreate: false)

        // when
        let result = handler.handleLink(try self.link("license"))

        // then
        #expect(result == .handle)
        try await self.waitEffect("안내 시트") { router.didShowActionSheetWith != nil }
        #expect(router.didShowActionSheetWith?.title == "widget.style.license::title".localized())
    }

    @MainActor
    @Test("이미 권한이 있으면 안내 없이 처리로 끝낸다")
    func handler_licenseLinkWithPermission_skipsGuide() async throws {
        // given
        let (handler, router) = self.makeHandler(canCreate: true)

        // when
        let result = handler.handleLink(try self.link("license"))
        await self.drainMainActor()

        // then
        #expect(result == .handle)
        #expect(router.didAskTopScene == false)
        #expect(router.didShowActionSheetWith == nil)
    }

    /// 안내는 MainActor 작업으로 뜬다 — 뒤에 넣은 작업이 끝나면 앞선 작업도 끝나 있다
    @MainActor
    private func drainMainActor() async {
        await Task { @MainActor in }.value
    }

    @Test("모르는 경로는 앱 업데이트가 필요하다고 답한다")
    func handler_unknownPath_needsUpdate() throws {
        // given
        let (handler, _) = self.makeHandler(canCreate: false)

        // when
        let result = handler.handleLink(try self.link("unknown"))

        // then
        #expect(result == .needUpdate)
    }

    @Test("안내를 띄울 화면이 없으면 안내를 띄우지 않는다")
    func handler_whenNoTopScene_skipsGuide() async throws {
        // given
        let (handler, router) = self.makeHandler(canCreate: false, hasTopScene: false)

        // when
        let result = handler.handleLink(try self.link("license"))

        // then
        #expect(result == .handle)
        try await self.waitEffect("최상단 확인") { router.didAskTopScene }
        #expect(router.didShowActionSheetWith == nil)
    }
}
