//
//  SharedDataStoreTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/03/24.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class SharedDataStoreTests: XCTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var store: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.store = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.store = nil
    }
}


extension SharedDataStoreTests {
    
    
    func testStore_putAndGetValue() {
        // given
        self.store.put(Int.self, key: "int", 100)
        // when
        let int = self.store.value(Int.self, key: "int")
        let notExist = self.store.value(Int.self, key: "int1")
        let wrongType = self.store.value(String.self, key: "int")
        
        // then
        XCTAssertEqual(int, 100)
        XCTAssertNil(notExist)
        XCTAssertNil(wrongType)
    }
    
    
    func testStore_putAndObserveValue() {
        // given
        let expect = expectation(description: "데이터 put 하고 observe")
        expect.expectedFulfillmentCount = 4
        
        // when
        let ints = self.waitOutputs(expect, for: self.store.observe(Int.self, key: "int")) {
            self.store.put(Int.self, key: "int", 1)
            self.store.put(Int.self, key: "int", 2)
            self.store.put(String.self, key: "int", "not int")
        }
        
        // then
        XCTAssertEqual(ints, [nil, 1, 2, nil])
    }
    
    func testStore_observeUpdatingValue() {
        // given
        let expect = expectation(description: "업데이트되는 값 구독")
        expect.expectedFulfillmentCount = 3
        
        // when
        let source = self.store.observe([String: Int].self, key: "dict")
        let dicts = self.waitOutputs(expect, for: source) {
            (0..<2).forEach { int in
                self.store.update([String: Int].self, key: "dict") {
                    return ($0 ?? [:]) |> key("k:\(int!)") .~ int
                }
            }
        }
        
        // then
        XCTAssertEqual(dicts, [
            nil,
            ["k:0": 0],
            ["k:0": 0, "k:1": 1],
        ])
    }
    
    func testStore_observeValueDeleting() {
        // given
        let expect = expectation(description: "삭제되는값 observe")
        expect.expectedFulfillmentCount = 5
        
        // when
        let values = self.waitOutputs(expect, for: self.store.observe(Int.self, key: "int")) {
            self.store.put(Int.self, key: "int", 100)
            self.store.delete("int")
            self.store.put(Int.self, key: "int", 101)
            self.store.clearAll()
        }
        
        // then
        XCTAssertEqual(values, [nil, 100, nil, 101, nil])
    }
    
    func testStore_clearWithFilter() {
        // given
        self.store.put(Int.self, key: "will_remove", 100)
        self.store.put(Int.self, key: "will_not_remove", 10)
        
        // when
        self.store.clearAll(filter: { $0 != "will_not_remove" })
        
        // then
        let intWillRemove = self.store.value(Int.self, key: "will_remove")
        let intWillNotRemove = self.store.value(Int.self, key: "will_not_remove")
        XCTAssertEqual(intWillRemove, nil)
        XCTAssertEqual(intWillNotRemove, 10)
    }
}


// MARK: - 계정 전환 초기화

extension SharedDataStoreTests {

    private func putAccountChangeFixture() {
        self.store.put([String].self, key: ShareDataKeys.todos.rawValue, ["todo"])
        self.store.put(String.self, key: ShareDataKeys.accountInfo.rawValue, "me")
        self.store.put([String].self, key: ShareDataKeys.googleCalendarEvents.rawValue, ["google-event"])
        self.store.put([String].self, key: ShareDataKeys.googleCalendarTags.rawValue, ["google-tag"])
        self.store.put([String].self, key: ShareDataKeys.appleCalendarEvents.rawValue, ["apple-event"])
        self.store.put([String].self, key: ShareDataKeys.externalCalendarAccounts.rawValue, ["account"])
        self.store.put(Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, [
            .custom("app-tag"),
            .externalCalendar(serviceId: "google", id: "cal-1")
        ])
    }

    private func storedStrings(_ key: ShareDataKeys) -> [String]? {
        return self.store.value([String].self, key: key.rawValue)
    }

    func testStore_whenAccountChanged_keepExternalCalendarData() {
        // given
        self.putAccountChangeFixture()

        // when
        self.store.clearAllForAccountChange()

        // then
        XCTAssertEqual(self.storedStrings(.googleCalendarEvents), ["google-event"])
        XCTAssertEqual(self.storedStrings(.googleCalendarTags), ["google-tag"])
        XCTAssertEqual(self.storedStrings(.appleCalendarEvents), ["apple-event"])
        XCTAssertEqual(self.storedStrings(.externalCalendarAccounts), ["account"])
    }

    func testStore_whenAccountChanged_clearAppAccountData() {
        // given
        self.putAccountChangeFixture()

        // when
        self.store.clearAllForAccountChange()

        // then
        XCTAssertEqual(self.storedStrings(.todos), nil)
        XCTAssertEqual(self.store.value(String.self, key: ShareDataKeys.accountInfo.rawValue), nil)
    }

    func testStore_whenAccountChanged_keepOnlyExternalCalendarOffTags() {
        // given
        self.putAccountChangeFixture()

        // when
        self.store.clearAllForAccountChange()

        // then
        let offTags = self.store.value(
            Set<EventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue
        )
        XCTAssertEqual(offTags, [.externalCalendar(serviceId: "google", id: "cal-1")])
    }

    func testStore_whenAccountChangedWithKeepingKey_keepThatKeyToo() {
        // given
        self.putAccountChangeFixture()

        // when
        self.store.clearAllForAccountChange(keeping: [.accountInfo])

        // then
        XCTAssertEqual(self.store.value(String.self, key: ShareDataKeys.accountInfo.rawValue), "me")
        XCTAssertEqual(self.storedStrings(.todos), nil)
    }
}
