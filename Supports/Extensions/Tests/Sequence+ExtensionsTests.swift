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
