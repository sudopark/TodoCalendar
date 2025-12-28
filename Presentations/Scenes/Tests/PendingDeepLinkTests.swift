//
//  PendingDeepLinkTests.swift
//  ScenesTests
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
@testable import Scenes


struct PendingDeepLinkTests {
    
    private var fullPath: String {
        "tc.app://calendar/event/todo?event_id=some&time=value"
    }
}

extension PendingDeepLinkTests {
    
    @Test func make_deepLink() {
        // given
        let link = URL(string: self.fullPath).flatMap {
            PendingDeepLink($0)
        }
        
        // when + then
        #expect(link?.fullURL.absoluteString == self.fullPath)
        #expect(link?.host == "calendar")
        #expect(link?.pendingPathComponents == ["event", "todo"])
        #expect(link?.queryParams.count == 2)
        #expect(link?.queryParams["event_id"] == "some")
        #expect(link?.queryParams["time"] == "value")
    }
    
    @Test func deepLink_removePaths() {
        // given
        var link = URL(string: self.fullPath).flatMap {
            PendingDeepLink($0)
        }
        
        // when
        let first = link?.removeFirstPath()
        let second = link?.removeFirstPath()
        let third = link?.removeFirstPath()
        
        // then
        #expect(first == "event")
        #expect(second == "todo")
        #expect(third == nil)
    }
}
