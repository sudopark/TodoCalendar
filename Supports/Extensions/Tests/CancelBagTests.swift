//
//  CancelBagTests.swift
//  Extensions
//
//  Created by sudo.park on 10/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine

@testable import Extensions


struct CancelBagTests {

    private final class Received: @unchecked Sendable {
        var values: [String] = []
    }

    private func subscribe(
        _ subject: PassthroughSubject<String, Never>,
        in bag: CancelBag,
        forKey key: AnyHashable,
        to received: Received
    ) {
        subject
            .sink { received.values.append($0) }
            .store(in: bag, forKey: key)
    }
}


// MARK: - 키별 취소

extension CancelBagTests {

    @Test("키로 취소하면 그 키의 구독만 끊긴다")
    func bag_whenCancelForKey_keepsOtherKeys() {
        // given
        let bag = CancelBag()
        let received = Received()
        let onKey1 = PassthroughSubject<String, Never>()
        let onKey2 = PassthroughSubject<String, Never>()
        self.subscribe(onKey1, in: bag, forKey: "key1", to: received)
        self.subscribe(onKey2, in: bag, forKey: "key2", to: received)

        // when
        bag.cancelAll(forKey: "key1")
        onKey1.send("key1")
        onKey2.send("key2")

        // then
        #expect(received.values == ["key2"])
    }

    @Test("없는 키로 취소해도 보관된 구독은 그대로 남는다")
    func bag_whenCancelForUnknownKey_keepsStoredSubscriptions() {
        // given
        let bag = CancelBag()
        let received = Received()
        let onKey1 = PassthroughSubject<String, Never>()
        self.subscribe(onKey1, in: bag, forKey: "key1", to: received)

        // when
        bag.cancelAll(forKey: "absent")
        onKey1.send("key1")

        // then
        #expect(received.values == ["key1"])
    }

    @Test("한 키에 쌓인 구독은 모두 살아 있다가 그 키를 취소할 때 함께 끊긴다")
    func bag_whenSeveralSubscriptionsShareKey_cancelsAllOfThem() {
        // given
        let bag = CancelBag()
        let received = Received()
        let first = PassthroughSubject<String, Never>()
        let second = PassthroughSubject<String, Never>()
        let onOtherKey = PassthroughSubject<String, Never>()
        self.subscribe(first, in: bag, forKey: "key1", to: received)
        self.subscribe(second, in: bag, forKey: "key1", to: received)
        self.subscribe(onOtherKey, in: bag, forKey: "key2", to: received)

        // when
        first.send("first")
        second.send("second")
        bag.cancelAll(forKey: "key1")
        first.send("first again")
        second.send("second again")
        onOtherKey.send("other")

        // then
        #expect(received.values == ["first", "second", "other"])
    }

    @Test("전체 취소는 키로 보관한 구독까지 끊는다")
    func bag_whenCancelAll_cancelsKeyedSubscriptionsToo() {
        // given
        let bag = CancelBag()
        let received = Received()
        let keyed = PassthroughSubject<String, Never>()
        let plain = PassthroughSubject<String, Never>()
        self.subscribe(keyed, in: bag, forKey: "key1", to: received)
        plain
            .sink { received.values.append($0) }
            .store(in: bag)

        // when
        bag.cancelAll()
        keyed.send("keyed")
        plain.send("plain")

        // then
        #expect(received.values.isEmpty)
    }
}
