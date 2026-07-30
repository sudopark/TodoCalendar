//
//  RemoteDateParserTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Repository


final class RemoteDateParserTests { }


// MARK: - ISO8601 파싱

extension RemoteDateParserTests {

    @Test func parser_parseISO8601WithFractionalSeconds() {
        // given
        let raw = "2026-08-26T00:00:00.000Z"
        // when
        let date = RemoteDateParser.parse(raw)
        // then
        #expect(date?.timeIntervalSince1970 == 1787702400)
    }

    // 서버가 밀리초를 빼도 날짜를 잃지 않아야 한다 — 한쪽 포맷만 받으면 통째로 nil 이 된다
    @Test func parser_parseISO8601WithoutFractionalSeconds() {
        // given
        let raw = "2026-08-26T00:00:00Z"
        // when
        let date = RemoteDateParser.parse(raw)
        // then
        #expect(date?.timeIntervalSince1970 == 1787702400)
    }

    @Test func parser_whenValueIsNil_returnsNil() {
        #expect(RemoteDateParser.parse(nil) == nil)
    }

    @Test func parser_whenValueIsNotString_returnsNil() {
        #expect(RemoteDateParser.parse(1787702400) == nil)
    }

    @Test func parser_whenStringIsNotDate_returnsNil() {
        #expect(RemoteDateParser.parse("not a date") == nil)
    }
}
