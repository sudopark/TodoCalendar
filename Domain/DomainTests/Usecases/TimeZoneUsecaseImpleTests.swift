//
//  TimeZoneUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/03.
//

import XCTest
import Combine
import UnitTestHelpKit
import Extensions

@testable import Domain


class TimeZoneUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private func makeUsecase(_ savedTimeZone: TimeZone? = nil) -> TimeZoneManagingUsecaseImple {
        
        let repository = StubTimezoneRepository()
        if let timeZone = savedTimeZone {
            repository.saveTimeZone(timeZone)
        }
        
        let dataStore = SharedDataStore()
        
        return TimeZoneManagingUsecaseImple(
            timeZoneRepository: repository,
            shareDataStore: dataStore
        )
    }
}


extension TimeZoneUsecaseImpleTests {
        
    func testUsecase_whenSubscribeCurrentTimeZone_startWithSavedTimeZone() {
        // given
        let expect = expectation(description: "timezone 정보 구독시에 저장되어있는 정보 같이 구독")
        let usecase = self.makeUsecase(TimeZone(abbreviation: "KST"))
        
        // when
        let timeZones = self.waitOutputs(expect, for: usecase.currentTimeZone)
        
        // then
        XCTAssertEqual(timeZones, [
            TimeZone(abbreviation: "KST")
        ])
    }
    
    func testUsecase_whenAfterSeleectTimeZone_updateCurrentTimeZone() {
        // given
        let expect = expectation(description: "timezone 선택 이후에 현재 timezone 정보 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(TimeZone(abbreviation: "KST"))
        
        // when
        let timeZones = self.waitOutputs(expect, for: usecase.currentTimeZone) {
            usecase.selectTimeZone(TimeZone(abbreviation: "UTC")!)
        }
            
        // then
        XCTAssertEqual(timeZones, [
            TimeZone(abbreviation: "KST"),
            TimeZone(abbreviation: "UTC")
        ])
    }
}
