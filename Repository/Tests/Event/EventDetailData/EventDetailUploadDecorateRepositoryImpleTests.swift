//
//  EventDetailUploadDecorateRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import SQLiteService
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository

@Suite("EventDetailUploadDecorateRepositoryImpleTests", .serialized)
final class EventDetailUploadDecorateRepositoryImpleTests: PublisherWaitable, LocalTestable {
    
    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()
    let spyEventUploadService: SpyEventUploadService = .init()
    var spyLocalStorage: EventDetailDataLocalStorageImple<EventDetailDataTable>!
    
    private func makeRepository(
        shouldLoadFail: Bool = false
    ) async throws -> EventDetailUploadDecorateRepositoryImple {
        
        let remoteAPI = StubRemoteAPI(responses: self.response)
        remoteAPI.shouldFailRequest = shouldLoadFail
        
        let remote = EventDetailRemoteImple(remoteAPI: remoteAPI)
        
        let local = EventDetailDataLocalStorageImple<EventDetailDataTable>(sqliteService: self.sqliteService)
        let detail = EventDetailData("dummy")
            |> \.memo .~ "memo"
        try await local.saveDetail(detail)
        self.spyLocalStorage = local
        
        return EventDetailUploadDecorateRepositoryImple(
            remote: remote, cacheStorage: local, uploadService: self.spyEventUploadService
        )
    }
}

extension EventDetailUploadDecorateRepositoryImpleTests {
    
    // load detail: cache + remote
    @Test func repository_loadDetail() async throws {
        try await self.runTestWithOpenClose("detail_tc1") {
            // given
            let expect = self.expectConfirm("load detail: cache + remote")
            expect.count = 2
            let repository = try await self.makeRepository()
            
            // when
            let load = repository.loadDetail("dummy")
            let details = try await self.outputs(expect, for: load)
            
            // then
            #expect(details.count == 2)
        }
    }
    
    // load detail: cache and remote not exits
    @Test func repository_loadDetail_notExistCase() async throws {
        try await self.runTestWithOpenClose("detail_tc2") {
            // given
            let expect = self.expectConfirm("load detail: cache and remote not exits")
            expect.count = 0
            let repository = try await self.makeRepository()
            
            // when
            let load = repository.loadDetail("not_exists")
            let details = try await self.outputs(expect, for: load)
            
            // then
            #expect(details.count == 0)
        }
    }
    
    // load detail: cache + remote fail ignore
    @Test func repository_whenLoadDetailFromRemoteFails_ignore() async throws {
        try await self.runTestWithOpenClose("detail_tc3") {
            // given
            let expect = self.expectConfirm("load detail: cache + remote fail ignore")
            let repository = try await self.makeRepository(shouldLoadFail: true)
            
            // when
            let load = repository.loadDetail("dummy")
            let details = try await self.outputs(expect, for: load)
            
            // then
            #expect(details.count == 1)
        }
    }
    
    // save detail
    @Test func repository_saveDetail() async throws {
        try await self.runTestWithOpenClose("detail_tc4") {
            // given
            let repository = try await self.makeRepository()
            
            // when
            let detail = EventDetailData("some")
                |> \.memo .~ "memo"
            let _ = try await repository.saveDetail(detail)
            
            // then
            let saved = try await self.spyLocalStorage.loadDetail(detail.eventId)
            #expect(saved != nil)
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.uuid } == [detail.eventId]
            )
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.dataType } == [.eventDetail]
            )
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask } == [false]
            )
        }
    }
    
    // remove detail
    @Test func repository_removeDetail() async throws {
        try await self.runTestWithOpenClose("detail_tc5") {
            // given
            let repository = try await self.makeRepository()
            
            // when
            try await repository.removeDetail("dummy")
            
            // then
            let saved = try await self.spyLocalStorage.loadDetail("dummy")
            #expect(saved == nil)
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.uuid } == ["dummy"]
            )
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.dataType } == [.eventDetail]
            )
            #expect(
                self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask } == [true]
            )
        }
    }
}


extension EventDetailUploadDecorateRepositoryImpleTests {
    
    private var singleDetailResponse: String {
        return """
        {
            "eventId": "dummy",
            "place": {
                "coordinate": {
                    "lat": 100.1, "long": 300.3
                },
                "name": "place name",
                "address": "address"
            },
            "url": "some url",
            "memo": "some"
        }
        """
    }
    
    private var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: EventDetailEndpoints.detail(eventId: "dummy"),
                resultJsonString: .success(self.singleDetailResponse)
            )
        ]
    }
}
