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

// MARK: - 격리 축에 매달린 저장소·host

extension AppEnvironmentTests {
    
    @Test("격리 실행에서는 외부 캘린더 DB 도 테스트 접두를 달아 실 파일과 갈린다")
    func externalCalendarDBPaths_inIsolatedRun_useTestPrefix() {
        // given & when
        let paths = AppEnvironment.externalCalendarDBPaths()
        
        // then
        #expect(paths.count == 2)
        #expect(paths.values.allSatisfy { $0.contains("/test_dummy_") } == true)
        #expect(paths.values.contains { $0.hasSuffix("_calendar.db") } == true)
    }
    
    @Test("격리 실행에서는 keychain 저장소 이름이 실 저장소와 갈린다")
    func keyChainStoreName_inIsolatedRun_isSeparatedFromProduction() {
        // given & when
        let name = AppEnvironment.keyChainStoreName
        
        // then
        #expect(name == "TodoCalendar.test")
    }
    
    @Test("격리 실행에서는 secrets 의 실 host 를 읽지 않고 도달 불가 주소로 떨어진다")
    func calendarAPIHost_inIsolatedRun_doesNotReadSecrets() {
        // given
        let secrets: [String: Any] = [
            "caleandar_api_host": "https://real.example.com",
            "emulator_caleandar_api_host": "https://emulator.example.com"
        ]
        
        // when
        let host = AppEnvironment.calendarAPIHost(secrets: secrets)
        
        // then
        #expect(host == "http://127.0.0.1:1")
    }
}
