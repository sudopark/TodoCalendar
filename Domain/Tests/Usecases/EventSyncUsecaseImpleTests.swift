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
    
    @Test func usecase_sync_noNeedToSync() async throws {
        // given
        let expect = self.expectConfirm("no need to sync")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .noNeedToSync)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[.eventTag] == nil)
        #expect(self.spyRepository.syncPageCountMap[.todo] == nil)
        #expect(self.spyRepository.syncPageCountMap[.schedule] == nil)
    }
    
    @Test func usecase_sync_migrationAll() async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .migrationNeeds)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[.eventTag] == 3)
        #expect(self.spyRepository.syncPageCountMap[.todo] == 3)
        #expect(self.spyRepository.syncPageCountMap[.schedule] == 3)
    }
    
    @Test func usecase_sync_() async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[.eventTag] == 3)
        #expect(self.spyRepository.syncPageCountMap[.todo] == 3)
        #expect(self.spyRepository.syncPageCountMap[.schedule] == 3)
    }
    
    @Test func usecase_syncFail() async throws {
        // given
        let expect = expectConfirm("migration all")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync, shouldFail: true)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true, false])
    }
    
    @Test func usecase_whenEventUploading_waitSync() async throws {
        // given
        let expect = expectConfirm("event uploading 중에는 sync 동작 대기")
        expect.count = 2
        let usecase = self.makeUsecase(checkResult: .needToSync)
        try await self.fakeEventUploadService.resume()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true])
    }
    
    @Test func usecase_whenTemporaryUserDataMigration_waitSync() async throws {
        // given
        let expect = expectConfirm("임시 유저데이터 마이그레이션 중에는 sync 동작 대기")
        expect.count = 2
        let usecase = self.makeUsecase(checkResult: .needToSync)
        self.fakeMigrationUsecase.startMigration()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
        }
        
        // then
        #expect(syncs == [false, true])
    }
    
    @Test func usecase_whenEventUploading_runSyncAfterUploadingEnd() async throws {
        // given
        let expect = expectConfirm("event uploading이 끝난 이후에 sync run")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)
        try await self.fakeEventUploadService.resume()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
            
            await self.fakeEventUploadService.pause()
        }
        
        // then
        #expect(syncs == [false, true, false])
    }
    
    @Test func usecase_whenAfterSync_notify() async throws {
        // given
        let usecase = self.makeUsecase(checkResult: .needToSync)
        
        // when + then
        try await confirmation("sync 종료 대기") { confirm in
            
            usecase.sync { confirm() }
            
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    @Test func usecase_cancelSync() async throws {
        // given
        let expect = expectConfirm("sync cancel")
        expect.count = 3; expect.timeout = .milliseconds(100)
        let usecase = self.makeUsecase(checkResult: .needToSync)
        try await self.fakeEventUploadService.resume()
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.sync()
            
            try await Task.sleep(for: .milliseconds(50))
            usecase.cancelSync()
            
            // should ignore
            await self.fakeEventUploadService.pause()
        }
        
        // then
        #expect(syncs == [false, true, false])
    }
    
    @Test func usecase_foreceSync() async throws {
        // given
        let expect = expectConfirm("force sync")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)
        
        // when
        let syncs = try await self.outputs(expect, for: usecase.isSyncInProgress) {
            usecase.forceSync()
        }
        
        // then
        #expect(syncs == [false, true, false])
        #expect(self.spyRepository.syncPageCountMap[.eventTag] == 3)
        #expect(self.spyRepository.syncPageCountMap[.todo] == 3)
        #expect(self.spyRepository.syncPageCountMap[.schedule] == 3)
    }
}


private final class StubEventSyncRepository: EventSyncRepository, @unchecked Sendable {
    
    var shouldFail: Bool = false
    var checkResult: EventSyncCheckRespose.CheckResult?
    var syncPageCountMap: [SyncDataType: Int] = [:]
    
    func clearSyncTimestamp() async throws {
        self.checkResult = .migrationNeeds
    }
    
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
            return response |> \.newSyncTime .~ 300
        } else {
            return response |> \.nextPageCursor .~ "next"
        }
    }
    
    func loadLatestSyncDataTimestamp() async throws -> TimeInterval? {
        return nil
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
