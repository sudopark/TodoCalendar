//
//  GoogleCalendarUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit
import TestDoubles

@testable import Domain

final class GoogleCalendarUsecaseImpleTests: PublisherWaitable {
    
    private let spyViewAppearanceStore: SpyGoogleCalendarViewAppearanceStore = .init()
    private let stubStore: SharedDataStore = .init()
    private let service = GoogleCalendarService(scopes: [.readOnly])
    
    var cancelBag: Set<AnyCancellable>! = []
    
    private func updateAccountIntegrated(_ hasAccount: Bool) {
        if hasAccount {
            let account = ExternalServiceAccountinfo(service.identifier, email: "email")
            self.stubStore.put(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue,
                [service.identifier: account]
            )
        } else {
            self.stubStore.put(
                [String: ExternalServiceAccountinfo].self,
                key: ShareDataKeys.externalCalendarAccounts.rawValue,
                [:]
            )
        }
    }
    
    private func makeUsecase(
        hasAccount: Bool
    ) -> GoogleCalendarUsecaseImple {
        let repository = PrivateStubRepository()
        self.updateAccountIntegrated(hasAccount)
        return .init(
            googleService: GoogleCalendarService(scopes: [.readOnly]),
            repository: repository,
            appearanceStore: self.spyViewAppearanceStore,
            sharedDataStore: self.stubStore
        )
    }
}


extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_whenPrepareAndHasAccount_updateColorsAtAppearanceStore() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when + 소두
        try await confirmation("prepare시 구캘 연동되어있으면 color 조회해서 appearance store에 저장") { confirm in
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                confirm()
            }
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    
    @Test func usecase_whenPrepareAndHasNoAccount_notUpdateColors() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: false)
        
        // when + then
        try await confirmation("prepare시 구캘 연동 안되어있으면 color 조회해서 안함", expectedCount: 0) { confirm in
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                confirm()
            }
            usecase.prepare()
            
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    
    @Test func usecase_whenGoogleCalendarAccountIntegrationChanged_updateColor() async throws {
        // given
        let usecase = self.makeUsecase(hasAccount: true)
        
        // when
        let hasColors = try await confirmation("연동여부에 따라 컬러 정보 스토어에 업데이트", expectedCount: 3) { confirm in
            
            var sender: [Bool] = []
            self.spyViewAppearanceStore.didUpdatecColors = { color in
                sender.append(self.spyViewAppearanceStore.color != nil)
                confirm()
            }
            self.spyViewAppearanceStore.didClearColor = {
                sender.append(self.spyViewAppearanceStore.color != nil)
                confirm()
            }
            
            usecase.prepare()
            try await Task.sleep(for: .milliseconds(10))
            
            self.updateAccountIntegrated(false)
            try await Task.sleep(for: .milliseconds(10))
            
            self.updateAccountIntegrated(true)
            try await Task.sleep(for: .milliseconds(10))
            
            return sender
        }
        
        // then
        #expect(hasColors == [true, false, true])
    }
}

extension GoogleCalendarUsecaseImpleTests {
    
    @Test func usecase_updateCalendarTag_byIntegrationStatusChanged() async throws {
        // given
        let expect = expectConfirm("연동 여부에 따라 구글 캘린더 태그정보 업데이트")
        expect.count = 4
        let usecase = self.makeUsecase(hasAccount: false)
        self.stubStore.put([EventTagId: any EventTag].self, key: ShareDataKeys.tags.rawValue, [
            .custom("some"): CustomEventTag(uuid: "custom", name: "name", colorHex: "hex")
        ])
        
        // when
        let tagSource = self.stubStore.observe(
            [EventTagId: any EventTag].self, key: ShareDataKeys.tags.rawValue
        )
        let tagLists = try await self.outputs(expect, for: tagSource) {
            usecase.prepare()
            
            self.updateAccountIntegrated(true)
            
            self.updateAccountIntegrated(false)
        }
        
        // then
        let idSets = tagLists.map { ts in ts?.map { $0.key } ?? [] }.map { Set($0) }
        #expect(idSets == [
            [.custom("some")],
            [.custom("some")],
            [
                .custom("some"),
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag1"),
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "tag2")
            ],
            [EventTagId.custom("some")],
        ])
    }
}


private final class PrivateStubRepository: GoogleCalendarRepository {
    
    func loadColors() -> AnyPublisher<GoogleCalendarColors, any Error> {
        let color = GoogleCalendarColors(
            calendars: ["0": .init(foregroundHex: "f0", backgroudHex: "b0")],
            events: ["1": .init(foregroundHex: "f1", backgroudHex: "b1")]
        )
        return Just(color)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
    
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendarEventTag], any Error> {
        let tags = [
            GoogleCalendarEventTag(id: "tag1", name: "tag1"),
            GoogleCalendarEventTag(id: "tag2", name: "tag2"),
        ]
        return Just(tags)
            .mapAsAnyError()
            .eraseToAnyPublisher()
    }
}

private final class SpyGoogleCalendarViewAppearanceStore: GoogleCalendarViewAppearanceStore, @unchecked Sendable {
    
    var color: GoogleCalendarColors?
    
    var didUpdatecColors: ((GoogleCalendarColors?) -> Void)?
    func apply(colors: GoogleCalendarColors) {
        self.color = colors
        self.didUpdatecColors?(colors)
    }
    
    var didClearColor: (() -> Void)?
    func clearGoogleCalendarColors() {
        self.color = nil
        self.didClearColor?()
    }
}
