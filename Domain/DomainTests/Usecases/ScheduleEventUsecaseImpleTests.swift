//
//  ScheduleEventUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/01.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class ScheduleEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubScheduleEventRepository!
    private var spyStore: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
        self.spyStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
        self.spyStore = nil
    }
    
    private func makeUsecase() -> ScheduleEventUsecaseImple {
        return ScheduleEventUsecaseImple(
            scheduleRepository: self.stubRepository,
            sharedDataStore: self.spyStore
        )
    }
    
    private func stubMakeFail() {
        self.stubRepository.shouldFailMake = true
    }
}

// MARK: - make case

extension ScheduleEventUsecaseImpleTests {
    
    // 생성
    func testUsecase_makeNewScheduleEvent() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ "some"
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertEqual(event?.name, "new")
        XCTAssertEqual(event?.eventTagId, "some")
    }
    
    // 생성 실패
    func testUsecase_makeNewScheduleEventFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubMakeFail()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ "some"
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertNil(event)
    }
}
