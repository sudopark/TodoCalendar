//
//  AppEnvironmentTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2026/09/09.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing

@testable import TodoCalendarApp


final class AppEnvironmentTests {
    
    // 앱을 호스트로 도는 유닛테스트라 실 컨테이너에 닿는다 — 남기면 일반 실행이 오염된다
    deinit {
        AppEnvironment.removeE2ERunMarker()
    }
    
    private func loadMarkerData() throws -> Data? {
        let container = try #require(
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppEnvironment.groupID
            )
        )
        return try? Data(contentsOf: container.appending(path: "e2e-run.marker"))
    }
}

// MARK: - e2e 마커 기록·삭제

extension AppEnvironmentTests {
    
    @Test("마커를 기록하면 넘긴 host 가 담긴 채 컨테이너에 남는다")
    func writeE2ERunMarker_storesGivenHost() throws {
        // given
        AppEnvironment.removeE2ERunMarker()
        
        // when
        AppEnvironment.writeE2ERunMarker(host: "http://127.0.0.1:9999")
        
        // then
        let data = try #require(try self.loadMarkerData())
        let marker = try #require(E2ERunMarker(data: data))
        #expect(marker.host == "http://127.0.0.1:9999")
        #expect(marker.isValid(at: Date()) == true)
    }
    
    @Test("마커를 지우면 컨테이너에서 사라진다")
    func removeE2ERunMarker_deletesWrittenMarker() throws {
        // given
        AppEnvironment.writeE2ERunMarker(host: "http://127.0.0.1:9999")
        
        // when
        AppEnvironment.removeE2ERunMarker()
        
        // then
        #expect(try self.loadMarkerData() == nil)
    }
}
