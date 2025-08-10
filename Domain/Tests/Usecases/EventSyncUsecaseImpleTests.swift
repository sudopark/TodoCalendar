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
import TestDoubles

@testable import Domain


final class EventSyncUsecaseImpleTests: PublisherWaitable {
    
    private let spyRepository = StubEventSyncRepository()
    private let fakeEventUploadService = FakeEventUploadService()
    private let fakeMigrationUsecase = FakeTemporaryUserDataMigrationUsecase()
    var cancelBag: Set<AnyCancellable>! = .init()
    
    private func makeUsecase(
        checkResult: EventSyncCheckRespose.CheckResult,
        shouldFail: Bool = false
    ) -> EventSyncUsecaseImple {
        self.spyRepository.checkResult = checkResult
        self.spyRepository.shouldFail = shouldFail
        
        let mediator = EventSyncMediatorImple(
            eventUploadService: self.fakeEventUploadService,
            migrationUsecase: self.fakeMigrationUsecase
        )
        
        return EventSyncUsecaseImple(
            syncRepository: self.spyRepository,
            eventSyncMediator: mediator
        )
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
    
    @Test func usecase_whenEventUploading_waitSync() async throws {
        // given
        let expect = expectConfirm("event uploading 중에는 sync 동작 대기")
        let usecase = self.makeUsecase(checkResult: .needToSync)
        try await self.fakeEventUploadService.resume()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(.eventTag)
        }
        
        // then
        #expect(syncs == [false])
    }
    
    @Test func usecase_whenTemporaryUserDataMigration_waitSync() async throws {
        // given
        let expect = expectConfirm("임시 유저데이터 마이그레이션 중에는 sync 동작 대기")
        let usecase = self.makeUsecase(checkResult: .needToSync)
        self.fakeMigrationUsecase.startMigration()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(.eventTag)
        }
        
        // then
        #expect(syncs == [false])
    }
    
    @Test func usecase_whenEventUploading_runSyncAfterUploadingEnd() async throws {
        // given
        let expect = expectConfirm("event uploading이 끝난 이후에 sync run")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)
        try await self.fakeEventUploadService.resume()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync(.eventTag)
            
            await self.fakeEventUploadService.pause()
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

private final class FakeTemporaryUserDataMigrationUsecase: StubTemporaryUserDataMigrationUescase, @unchecked Sendable {
    
    private let isMigratingSubject = CurrentValueSubject<Bool, Never>(false)
    
    override func startMigration() {
        self.isMigratingSubject.send(true)
    }
    
    override var isMigrating: AnyPublisher<Bool, Never> {
        return self.isMigratingSubject.eraseToAnyPublisher()
    }
}
