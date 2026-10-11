//
//  ApplicationDeepLinkHandlerImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Scenes

@testable import TodoCalendarApp


private final class SpyDeepLinkHandler: DeepLinkHandler, @unchecked Sendable {

    private(set) var didHandleLinks: [PendingDeepLink] = []
    func handleLink(_ link: PendingDeepLink) -> DeepLinkHandleResult {
        self.didHandleLinks.append(link)
        return .handle
    }
}


struct ApplicationDeepLinkHandlerImpleTests {

    private var widgetLicenseURL: URL {
        return URL(string: "tc.app://widget/license")!
    }

    @Test("위젯 핸들러가 붙기 전에 온 위젯 링크는 붙을 때 넘긴다")
    func handler_whenWidgetLinkBeforeAttach_passesItOnAttach() {
        // given
        let handler = ApplicationDeepLinkHandlerImple()
        let widgetHandler = SpyDeepLinkHandler()

        // when
        let handled = handler.handleLink(self.widgetLicenseURL)
        let passedBeforeAttach = widgetHandler.didHandleLinks.count
        handler.attach(widgetHandler: widgetHandler)

        // then
        #expect(handled == true)
        #expect(passedBeforeAttach == 0)
        #expect(widgetHandler.didHandleLinks.map { $0.pendingPathComponents } == [["license"]])
    }

    @Test("위젯 핸들러가 붙은 뒤의 위젯 링크는 바로 넘긴다")
    func handler_whenWidgetLinkAfterAttach_passesItImmediately() {
        // given
        let handler = ApplicationDeepLinkHandlerImple()
        let widgetHandler = SpyDeepLinkHandler()
        handler.attach(widgetHandler: widgetHandler)

        // when
        let handled = handler.handleLink(self.widgetLicenseURL)

        // then
        #expect(handled == true)
        #expect(widgetHandler.didHandleLinks.map { $0.host } == ["widget"])
    }

    @Test("보류한 위젯 링크는 한 번만 넘긴다")
    func handler_whenAttachedTwice_passesPendingLinkOnce() {
        // given
        let handler = ApplicationDeepLinkHandlerImple()
        let first = SpyDeepLinkHandler()
        let second = SpyDeepLinkHandler()
        _ = handler.handleLink(self.widgetLicenseURL)

        // when
        handler.attach(widgetHandler: first)
        handler.attach(widgetHandler: second)

        // then
        #expect(first.didHandleLinks.count == 1)
        #expect(second.didHandleLinks.isEmpty)
    }
}
