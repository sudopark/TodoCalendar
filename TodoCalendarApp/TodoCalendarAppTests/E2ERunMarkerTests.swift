//
//  E2ERunMarkerTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2026/09/09.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing

@testable import TodoCalendarApp


final class E2ERunMarkerTests {
    
    private func makeData(_ payload: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

// MARK: - 판독

extension E2ERunMarkerTests {
    
    @Test("host 와 만료 시각이 담긴 페이로드를 읽어들인다")
    func whenDataHasHostAndExpiry_parses() {
        // given
        let data = self.makeData([
            "host": "http://127.0.0.1:9999", "expiresAt": 1_800_000_000.0
        ])
        
        // when
        let marker = E2ERunMarker(data: data)
        
        // then
        #expect(marker?.host == "http://127.0.0.1:9999")
        #expect(marker?.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
    }
    
    @Test("JSON 이 아닌 데이터는 마커로 읽지 않는다")
    func whenDataIsMalformed_returnsNil() {
        // given
        let data = Data("not a json".utf8)
        
        // when
        let marker = E2ERunMarker(data: data)
        
        // then
        #expect(marker == nil)
    }
    
    @Test("만료 시각이 빠진 페이로드는 마커로 읽지 않는다")
    func whenExpiryKeyMissing_returnsNil() {
        // given
        let data = self.makeData(["host": "http://127.0.0.1:9999"])
        
        // when
        let marker = E2ERunMarker(data: data)
        
        // then
        #expect(marker == nil)
    }
}

// MARK: - 만료

extension E2ERunMarkerTests {
    
    private func makeMarker(expiresAt: TimeInterval) -> E2ERunMarker? {
        return E2ERunMarker(
            data: self.makeData(["host": "http://127.0.0.1:9999", "expiresAt": expiresAt])
        )
    }
    
    @Test("만료 시각이 지난 마커는 유효하지 않다")
    func whenExpiresAtIsPast_isNotValid() {
        // given
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let marker = self.makeMarker(expiresAt: 1_799_999_999)
        
        // when
        let isValid = marker?.isValid(at: now)
        
        // then
        #expect(isValid == false)
    }
    
    @Test("만료 시각이 남은 마커는 유효하다")
    func whenExpiresAtIsFuture_isValid() {
        // given
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let marker = self.makeMarker(expiresAt: 1_800_000_001)
        
        // when
        let isValid = marker?.isValid(at: now)
        
        // then
        #expect(isValid == true)
    }
}

// MARK: - 기록

extension E2ERunMarkerTests {
    
    @Test("기록한 마커를 다시 읽으면 host 와 만료 시각이 보존된다")
    func whenEncodedMarkerIsParsedBack_keepsHostAndExpiry() throws {
        // given
        let marker = E2ERunMarker(
            host: "http://127.0.0.1:9999",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        
        // when
        let restored = E2ERunMarker(data: try marker.encoded())
        
        // then
        #expect(restored?.host == "http://127.0.0.1:9999")
        #expect(restored?.expiresAt == Date(timeIntervalSince1970: 1_800_000_000))
    }
}
