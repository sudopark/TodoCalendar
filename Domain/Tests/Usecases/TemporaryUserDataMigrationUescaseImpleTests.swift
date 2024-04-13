//
//  TemporaryUserDataMigrationUescaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Combine
import Extensions
import UnitTestHelpKit

@testable import Domain

class TemporaryUserDataMigrationUescaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubRepository!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
    }
    
    private func makeUsecase() -> TemporaryUserDataMigrationUescaseImple {
        return .init(migrationRepository: self.stubRepository)
    }
}

extension TemporaryUserDataMigrationUescaseImpleTests {
    
    // check is need
    func testUsecase_checkIsNeed() {
        // given
        func parameterizeTest(
            _ description: String,
            expectIsNeeds: [Bool],
            _ stubbing: @escaping (StubRepository) -> Void
        ) {
            // given
            let expect = expectation(description: description)
            expect.expectedFulfillmentCount = expectIsNeeds.count
            stubbing(self.stubRepository)
            let usecase = self.makeUsecase()
            
            // when
            let isNeeds = self.waitOutputs(expect, for: usecase.isNeedMigration) {
                usecase.checkIsNeedMigration()
            }
            
            // then
            XCTAssertEqual(isNeeds, expectIsNeeds)
        }
        // when + then
        parameterizeTest("미이그레이션 불필요함", expectIsNeeds: [false]) {
            $0.stubMigrationTargetEventCountLoadResult = .success(0)
        }
        parameterizeTest("마이그레이션 필요함", expectIsNeeds: [false, true]) {
            $0.stubMigrationTargetEventCountLoadResult = .success(1)
        }
        parameterizeTest("마이그레이션 필요여부 체크 실패시 불필요함으로 간주", expectIsNeeds: [false]) {
            $0.stubMigrationTargetEventCountLoadResult = .failure(RuntimeError("failed"))
        }
    }
    
    // check migration need event count
    func testUsecase_checkMigrationNeedEventCounts() {
        // given
        func parameterizeTest(
            _ description: String,
            expectNeedCounts: [Int],
            _ stubbing: @escaping (StubRepository) -> Void
        ) {
            // given
            let expect = expectation(description: description)
            expect.expectedFulfillmentCount = expectNeedCounts.count
            stubbing(self.stubRepository)
            let usecase = self.makeUsecase()
            
            // when
            let counts = self.waitOutputs(expect, for: usecase.migrationNeedEventCount) {
                usecase.checkIsNeedMigration()
            }
            
            // then
            XCTAssertEqual(counts, expectNeedCounts)
        }
        // when + then
        parameterizeTest("미이그레이션 불필요함", expectNeedCounts: [0]) {
            $0.stubMigrationTargetEventCountLoadResult = .success(0)
        }
        parameterizeTest("마이그레이션 필요함", expectNeedCounts: [0, 1]) {
            $0.stubMigrationTargetEventCountLoadResult = .success(1)
        }
        parameterizeTest("마이그레이션 필요여부 체크 실패시 불필요함으로 간주", expectNeedCounts: [0]) {
            $0.stubMigrationTargetEventCountLoadResult = .failure(RuntimeError("failed"))
        }
    }
}

extension TemporaryUserDataMigrationUescaseImpleTests {
    
    // migration -> success
    func testUsecase_migrationSuccess() {
        // given
        let expect = expectation(description: "마이그레이션 성공")
        let usecase = self.makeUsecase()
        
        // when
        let result = self.waitFirstOutput(expect, for: usecase.migrationResult) {
            usecase.startMigration()
        }
        
        // then
        XCTAssertEqual(result?.isSuccess, true)
    }
    
    // migration -> failed
    func testUsecase_migrationFails() {
        // given
        func parameterizeTest(
            _ description: String,
            expectIsFail: Bool = true,
            _ stubbing: @escaping (StubRepository) -> Void
        ) {
            // given
            self.stubRepository = .init()
            stubbing(self.stubRepository)
            let expect = expectation(description: description)
            let usecase = self.makeUsecase()
            
            // when
            let result = self.waitFirstOutput(expect, for: usecase.migrationResult) {
                usecase.startMigration()
            }
            
            // then
            if expectIsFail {
                XCTAssertEqual(result?.isSuccess, false)
            } else {
                XCTAssertEqual(result?.isSuccess, true)
            }
        }
        
        
        // when + then
        parameterizeTest("이벤트 태그 마이그레이션 실패시 실패") { $0.stubMigrateEventTagResult = .failure(RuntimeError("failed")) }
        parameterizeTest("todo event 마이그레이션 실패시 실패") { $0.stubMigrateTodoResult = .failure(RuntimeError("failed")) }
        parameterizeTest("schedule event 마이그레이션 실패시 실패") { $0.stubMigrateScheduleResult = .failure(RuntimeError("failed")) }
        parameterizeTest("event detail 마이그레이션 실패는 성공으로 간주", expectIsFail: false) { $0.stubMigrateEventDetailResult = .failure(RuntimeError("failed")) }
        parameterizeTest("임시유저 데이터 삭제 실패는 성공으로 간주", expectIsFail: false) { $0.stubClearDataResult = .failure(RuntimeError("failed")) }
    }
    
    // migration -> update is migrating
    func testUsecase_whenMigrating_updateIsMigrating() {
        // given
        func parameterizeTest(whenSuccess: Bool) {
            // given
            if !whenSuccess {
                self.stubRepository.stubMigrateTodoResult = .failure(RuntimeError("failed"))
            }
            let expect = expectation(description: "마이그레이션 중에는 마이그레이션 중임을 알림")
            expect.expectedFulfillmentCount = 3
            let usecase = self.makeUsecase()
            
            // when
            let isMigrating = self.waitOutputs(expect, for: usecase.isMigrating) {
                usecase.startMigration()
            }
            
            // then
            XCTAssertEqual(isMigrating, [false, true, false])
        }
        
        // when + then
        parameterizeTest(whenSuccess: true)
        parameterizeTest(whenSuccess: false)
    }
    
    // migration end -> update event count
    func testUsecase_whenAfterMigration_updateMigrationNeedCounts() {
        // given
        func parameterizeTest(whenSuccess: Bool, expectCounts: [Int]) {
            // given
            self.stubRepository = .init()
            self.stubRepository.stubMigrationTargetEventCountLoadResult = .success(100)
            if !whenSuccess {
                self.stubRepository.stubMigrateScheduleResult = .failure(RuntimeError("failed"))
            }
            let expect = expectation(description: "마이그레이션 이후 마이그레이션 필요 이벤트 카운트 업데이트")
            expect.expectedFulfillmentCount = 3
            let usecase = self.makeUsecase()
            
            // when
            let counts = self.waitOutputs(expect, for: usecase.migrationNeedEventCount) {
                usecase.checkIsNeedMigration()
                
                usecase.startMigration()
            }
            
            // then
            XCTAssertEqual(counts, expectCounts)
        }
        
        // when + then
        parameterizeTest(whenSuccess: true, expectCounts: [0, 100, 0])
        parameterizeTest(whenSuccess: false, expectCounts: [0, 100, 90])
    }
}


private final class StubRepository: TemporaryUserDataMigrationRepository {
    
    var stubMigrationTargetEventCountLoadResult: Result<Int, any Error> = .success(0)
    func loadMigrationNeedEventCount() async throws -> Int {
        return try self.stubMigrationTargetEventCountLoadResult.get()
    }
    
    var stubMigrateEventTagResult: Result<Void, any Error> = .success(())
    func migrateEventTags() async throws {
        return try self.stubMigrateEventTagResult.get()
    }
    
    var stubMigrateTodoResult: Result<Void, any Error> = .success(())
    func migrateTodoEvents() async throws {
        switch self.stubMigrateTodoResult {
        case .success:
            let newCount = (try self.stubMigrationTargetEventCountLoadResult.get() - 10) |> { max(0, $0) }
            self.stubMigrationTargetEventCountLoadResult = .success(newCount)
            
        case .failure(let error):
            throw error
        }
    }
    
    var stubMigrateScheduleResult: Result<Void, any Error> = .success(())
    func migrateScheduleEvents() async throws {
        return try self.stubMigrateScheduleResult.get()
    }
    
    var stubMigrateEventDetailResult: Result<Void, any Error> = .success(())
    func migrateEventDetails() async throws {
        return try self.stubMigrateEventDetailResult.get()
    }
    
    var stubClearDataResult: Result<Void, any Error> = .success(())
    func clearTemporaryUserData() async throws {
        switch self.stubClearDataResult {
        case .success:
            self.stubMigrationTargetEventCountLoadResult = .success(0)
            
        case .failure(let error):
            throw error
        }
    }
}

private extension Result {
    
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }
}
