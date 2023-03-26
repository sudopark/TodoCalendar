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
}
