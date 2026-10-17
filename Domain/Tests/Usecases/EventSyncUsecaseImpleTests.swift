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


final class EventSyncUsecaseImpleTests: PublisherWaitable, AsyncEffectWaitable {
    
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

    @Test func usecase_whenMigrationNeeds_syncStatusIsFullSyncing() async throws {
        // given
        let expect = expectConfirm("migration 이 필요하면 전체 sync 상태로 알림")
        expect.count = 4
        let usecase = self.makeUsecase(checkResult: .migrationNeeds)

        // when
        let statuses = try await self.outputs(expect, for: usecase.syncStatus) {
            usecase.sync()
        }

        // then
        #expect(statuses == [.idle, .incrementalSyncing, .fullSyncing, .idle])
    }

    @Test func usecase_whenNeedToSync_syncStatusIsIncrementalSyncing() async throws {
        // given
        let expect = expectConfirm("증분 sync 는 전체 sync 상태로 올라가지 않음")
        expect.count = 3
        let usecase = self.makeUsecase(checkResult: .needToSync)

        // when
        let statuses = try await self.outputs(expect, for: usecase.syncStatus) {
            usecase.sync()
        }

        // then
        #expect(statuses == [.idle, .incrementalSyncing, .idle])
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
        expect.count = 3; expect.timeout = .seconds(1)
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


// MARK: - 앞 sync 가 끝나기 전에 다시 sync 를 걸면

extension EventSyncUsecaseImpleTests {

    @Test("취소된 앞 sync 는 끝까지 돌아도 자기 완료를 통지하지 않는다")
    func sync_whenCancelledSyncRunToEnd_doesNotNotifyItsCompletion() async throws {
        // given
        let usecase = self.makeUsecase(checkResult: .needToSync)
        let completions = Recorder<String>()
        let helds = try await self.holdCancelledAndRestartedSync(usecase) { completions.record($0) }

        // when
        try await helds.finishCancelledSync()

        // then
        #expect(completions.recorded.isEmpty)
    }

    @Test("새 sync 가 끝나면 그 sync 의 완료만 통지된다")
    func sync_whenRestartedSyncEnd_notifiesItsCompletionOnly() async throws {
        // given
        let usecase = self.makeUsecase(checkResult: .needToSync)
        let completions = Recorder<String>()
        let helds = try await self.holdCancelledAndRestartedSync(usecase) { completions.record($0) }
        try await helds.finishCancelledSync()

        // when
        helds.finishRestartedSync()

        // then
        try await self.waitEffect("새 sync 의 완료 통지") {
            completions.recorded == ["restarted"]
        }
    }

    @Test("취소된 앞 sync 가 끝까지 돌아도 sync 진행 표시는 내려가지 않는다")
    func sync_whenCancelledSyncRunToEnd_keepsSyncInProgress() async throws {
        // given
        let usecase = self.makeUsecase(checkResult: .needToSync)
        let syncings = self.recordSyncInProgress(usecase)
        let helds = try await self.holdCancelledAndRestartedSync(usecase)

        // when
        try await helds.finishCancelledSync()

        // then
        #expect(syncings.recorded == [false, true, false, true])
    }

    @Test("새 sync 가 끝나야 sync 진행 표시가 내려간다")
    func sync_whenRestartedSyncEnd_clearsSyncInProgress() async throws {
        // given
        let usecase = self.makeUsecase(checkResult: .needToSync)
        let syncings = self.recordSyncInProgress(usecase)
        let helds = try await self.holdCancelledAndRestartedSync(usecase)
        try await helds.finishCancelledSync()

        // when
        helds.finishRestartedSync()

        // then
        try await self.waitEffect("새 sync 의 종료") {
            syncings.recorded == [false, true, false, true, false]
        }
    }
}


// MARK: - 두 sync 를 check 지점에 붙잡아 두기

extension EventSyncUsecaseImpleTests {

    fileprivate struct HeldSyncs {
        let finishCancelledSync: () async throws -> Void
        let finishRestartedSync: () -> Void
    }

    fileprivate func recordSyncInProgress(_ usecase: EventSyncUsecaseImple) -> Recorder<Bool> {
        let syncings = Recorder<Bool>()
        usecase.isSyncInProgress
            .sink(receiveValue: { syncings.record($0) })
            .store(in: &self.cancelBag)
        return syncings
    }

    /// `sync()` 는 첫 줄이 `cancelSync()` 라 두 번 부르면 앞 task 가 취소된다. 둘 다 dataType 루프의
    /// check 지점에 붙잡아 둔 뒤, 취소된 쪽과 새 쪽을 따로 끝까지 진행시킬 수 있게 돌려준다.
    fileprivate func holdCancelledAndRestartedSync(
        _ usecase: EventSyncUsecaseImple,
        completed: (@Sendable (String) -> Void)? = nil
    ) async throws -> HeldSyncs {

        let gate = self.spyRepository.checkGate
        gate.holdNext(2)

        usecase.sync { completed?("cancelled") }
        await gate.waitUntilHeld()

        usecase.sync { completed?("restarted") }
        await gate.waitUntilHeld()

        return .init(
            finishCancelledSync: { [spyRepository] in
                gate.releaseHeld()
                try await self.waitEffect("취소된 sync 가 모든 dataType 을 끝까지 돎") {
                    spyRepository.isAllDataTypesSynced
                }
                try await Task.sleep(for: .milliseconds(50))
            },
            finishRestartedSync: { gate.releaseHeld() }
        )
    }
}


private final class StubEventSyncRepository: EventSyncRepository, @unchecked Sendable {
    
    var shouldFail: Bool = false
    var checkResult: EventSyncCheckRespose.CheckResult?
    
    let checkGate = SyncCheckGate()

    private let lock = NSLock()
    private var pageCountMap: [SyncDataType: Int] = [:]

    var syncPageCountMap: [SyncDataType: Int] {
        return self.lock.withLock { self.pageCountMap }
    }
    
    func clearSyncTimestamp() async throws {
        self.checkResult = .migrationNeeds
    }
    
    func checkIsNeedSync(
        for dataType: SyncDataType
    ) async throws -> EventSyncCheckRespose {
        
        await self.checkGate.passOrHold()

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
        
        self.lock.withLock { self.pageCountMap[dataType] = 1 }
        
        let response: EventSyncResponse<T> = .init()
            |> \.nextPageCursor .~ "next"
        return response
    }
    
    func continueSync<T: Sendable>(
        for dataType: SyncDataType, cursor: String, pageSize: Int
    ) async throws -> EventSyncResponse<T> {
        
        let pageCount: Int = self.lock.withLock {
            let next = (self.pageCountMap[dataType] ?? 0) + 1
            self.pageCountMap[dataType] = next
            return next
        }
        
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


extension StubEventSyncRepository {

    var isAllDataTypesSynced: Bool {
        let map = self.syncPageCountMap
        return [SyncDataType.eventTag, .todo, .schedule].allSatisfy { map[$0] == 3 }
    }
}


// sync 가 dataType 루프 안에서 멈춰 서는 지점 — 취소 시점과 재개 시점을 테스트가 가른다.
// withCheckedContinuation 은 Task 취소로 깨지 않아서 취소된 task 도 여기 붙잡힌다
private final class SyncCheckGate: @unchecked Sendable {

    private let lock = NSLock()
    private var holdRemains: Int = 0
    private var heldSyncs: [CheckedContinuation<Void, Never>] = []
    private var unobservedHolds: Int = 0
    private var holdObserver: CheckedContinuation<Void, Never>?

    func holdNext(_ count: Int) {
        self.lock.withLock { self.holdRemains = count }
    }

    /// sync 하나가 새로 붙잡힐 때까지 기다린다.
    func waitUntilHeld() async {
        await withCheckedContinuation { observing in
            let alreadyHeld: Bool = self.lock.withLock {
                guard self.unobservedHolds > 0 else {
                    self.holdObserver = observing
                    return false
                }
                self.unobservedHolds -= 1
                return true
            }
            if alreadyHeld { observing.resume() }
        }
    }

    /// 붙잡아 둔 sync 중 가장 먼저 걸린 하나를 끝까지 진행시킨다.
    func releaseHeld() {
        let held: CheckedContinuation<Void, Never>? = self.lock.withLock {
            return self.heldSyncs.isEmpty ? nil : self.heldSyncs.removeFirst()
        }
        held?.resume()
    }

    func passOrHold() async {
        let shouldHold: Bool = self.lock.withLock {
            guard self.holdRemains > 0 else { return false }
            self.holdRemains -= 1
            return true
        }
        guard shouldHold else { return }

        await withCheckedContinuation { held in
            let observer: CheckedContinuation<Void, Never>? = self.lock.withLock {
                self.heldSyncs.append(held)
                guard let observer = self.holdObserver else {
                    self.unobservedHolds += 1
                    return nil
                }
                self.holdObserver = nil
                return observer
            }
            observer?.resume()
        }
    }
}


private final class Recorder<T>: @unchecked Sendable {

    private let lock = NSLock()
    private var values: [T] = []

    func record(_ value: T) {
        self.lock.withLock { self.values.append(value) }
    }

    var recorded: [T] {
        return self.lock.withLock { self.values }
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
