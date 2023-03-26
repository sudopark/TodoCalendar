//
//  SharedDataStoreTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/03/24.
//

import XCTest
import Combine
import UnitTestHelpKit

@testable import Domain


final class SharedDataStoreTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    private var store: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancellables = []
        self.store = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancellables = nil
        self.store = nil
    }
}


extension SharedDataStoreTests {
    
    
    func testStore_putAndObserveValue() {
        // given
        let expect = expectation(description: "데이터 put 하고 observe")
        expect.expectedFulfillmentCount = 4
        var ints: [Int?] = []
        
        // when
        self.store.observe(Int.self, key: "int")
            .sink(receiveValue: {
                ints.append($0)
                expect.fulfill()
            })
            .store(in: &self.cancellables)
        self.store.put(Int.self, key: "int", 1)
        self.store.put(Int.self, key: "int", 2)
        self.store.put(String.self, key: "int", "not int")
        self.wait(for: [expect], timeout: 0.001)
        
        // then
        XCTAssertEqual(ints, [nil, 1, 2, nil])
    }
}
