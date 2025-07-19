//
//  EventSyncUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 7/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain


final class EventSyncUsecaseImpleTests: PublisherWaitable {
    
    private let spyRepository = StubEventSyncRepository()
    var cancelBag: Set<AnyCancellable>! = .init()
    
    private func makeUsecase(
        checkResult: EventSyncCheckRespose.CheckResult,
        shouldFail: Bool = false
    ) -> EventSyncUsecaseImple {
        self.spyRepository.checkResult = checkResult
        self.spyRepository.shouldFail = shouldFail
        
        return EventSyncUsecaseImple(syncRepository: self.spyRepository)
    }
}

extension EventSyncUsecaseImpleTests {
    
    @Test("no need to sync case", arguments: [SyncDataType.eventTag, .todo, .schedule])
    func usecase_sync_noNeedToSync(_ dataType: SyncDataType) async throws {
        // given
        let expect = self.expectConfirm("no need to sync")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .noNeedToSync)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(dataType)
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[dataType] == nil)
    }
    
    @Test("sync - migration all", arguments: [SyncDataType.eventTag, .todo, .schedule])
    func usecase_sync_migrationAll(_ dataType: SyncDataType) async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .migrationNeeds)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(dataType)
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[dataType] == 3)
    }
    
    @Test("sync", arguments: [SyncDataType.eventTag, .todo, .schedule])
    func usecase_sync_(_ dataType: SyncDataType) async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(dataType)
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[dataType] == 3)
    }
    
    @Test("sync fail", arguments: [SyncDataType.eventTag, .todo, .schedule])
    func usecase_syncFail(_ dataType: SyncDataType) async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync, shouldFail: true)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(dataType)
        }
        
        // then
        #expect(syncs == [false, true, false])
    }
}


private final class StubEventSyncRepository: EventSyncRepository, @unchecked Sendable {
    
    var shouldFail: Bool = false
    var checkResult: EventSyncCheckRespose.CheckResult?
    var syncPageCountMap: [SyncDataType: Int] = [:]
    
    func checkIsNeedSync(
        for dataType: SyncDataType
    ) async throws -> EventSyncCheckRespose {
        
        guard !self.shouldFail
        else {
            throw RuntimeError("failed")
        }
        
        let timestamp: Int? = self.checkResult == .needToSync ? 200 : nil
        let response = EventSyncCheckRespose(result: self.checkResult ?? .noNeedToSync)
            |> \.startTimestamp .~ timestamp
        return response
    }
    
    func startSync<T: Sendable>(
        for dataType: SyncDataType, startFrom timestamp: Int?, pageSize: Int
    ) async throws -> EventSyncResponse<T> {
        
        self.syncPageCountMap[dataType] = 1
        
        let response: EventSyncResponse<T> = .init()
            |> \.nextPageCursor .~ "next"
        return response
    }
    
    func continueSync<T: Sendable>(
        for dataType: SyncDataType, cursor: String, pageSize: Int
    ) async throws -> EventSyncResponse<T> {
        
        let pageCount = (self.syncPageCountMap[dataType] ?? 0) + 1
        self.syncPageCountMap[dataType] = pageCount
        
        let isLast = pageCount == 3
        
        let response: EventSyncResponse<T> = .init()
        if isLast {
            return response |> \.newSyncTime .~ .init(dataType, 300)
        } else {
            return response |> \.nextPageCursor .~ "next"
        }
    }
}
