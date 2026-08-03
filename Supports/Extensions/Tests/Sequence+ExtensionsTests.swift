//
//  Sequence+ExtensionsTests.swift
//  ExtensionsTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import Extensions


struct SequenceRemoveDuplicatesTests {

    private struct Item: Equatable {
        let key: String
        let tag: Int
    }

    @Test("같은 key의 첫 원소만 남고 순서는 유지된다")
    func removeDuplicates_keepsFirstAndPreservesOrder() {
        // given
        let items = [
            Item(key: "a", tag: 1),
            Item(key: "b", tag: 2),
            Item(key: "a", tag: 3),
            Item(key: "c", tag: 4),
            Item(key: "b", tag: 5)
        ]

        // when
        let result = items.removeDuplicates { $0.key }

        // then
        #expect(result == [
            Item(key: "a", tag: 1),
            Item(key: "b", tag: 2),
            Item(key: "c", tag: 4)
        ])
    }

    @Test("중복이 없으면 원본을 그대로 낸다")
    func removeDuplicates_whenNoDuplicates_returnsAll() {
        // given
        let items = [Item(key: "a", tag: 1), Item(key: "b", tag: 2)]

        // when
        let result = items.removeDuplicates { $0.key }

        // then
        #expect(result == items)
    }

    @Test("빈 시퀀스는 빈 배열을 낸다")
    func removeDuplicates_whenEmpty_returnsEmpty() {
        // given
        let items: [Item] = []

        // when
        let result = items.removeDuplicates { $0.key }

        // then
        #expect(result.isEmpty == true)
    }
}


// MARK: - joinedNonEmpty

struct SequenceJoinedNonEmptyTests {

    @Test("빈 조각은 빼고 잇는다")
    func joinedNonEmpty_skipsEmptyElements() {
        // given
        let texts = ["매주 월", "", "오전 7:00"]

        // when
        let joined = texts.joinedNonEmpty(separator: " · ")

        // then
        #expect(joined == "매주 월 · 오전 7:00")
    }

    @Test("전부 비어 있으면 빈 문자열을 낸다")
    func joinedNonEmpty_whenAllEmpty_returnsEmpty() {
        // given
        let texts = ["", ""]

        // when
        let joined = texts.joinedNonEmpty(separator: " · ")

        // then
        #expect(joined == "")
    }

    @Test("남는 조각이 하나면 구분자가 붙지 않는다")
    func joinedNonEmpty_whenSingleRemains_hasNoSeparator() {
        // given
        let texts = ["", "D-14", ""]

        // when
        let joined = texts.joinedNonEmpty(separator: " · ")

        // then
        #expect(joined == "D-14")
    }
}
