//
//  UserNotificationUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import UnitTestHelpKit

@testable import Domain


final class UserNotificationUsecaseImpleTests {
    
    private let spyRepository = StubRepository()
    
    private func makeUsecase() -> UserNotificationUsecaseImple {
        return UserNotificationUsecaseImple(
            repository: self.spyRepository,
            deviceInfoFetchService: StubDeviceInfoFetchService()
        )
    }
}

extension UserNotificationUsecaseImpleTests {
    
    @Test func usecase_register() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        try await usecase.register("userId", fcmToken: "token")
        
        // then
        #expect(self.spyRepository.didRegisterWithDeviceInfo?.deviceModel == "model")
    }
    
    @Test func usecase_unregister() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        try await usecase.unregister("userId")
    }
}


private final class StubRepository: UserNotificationRepository, @unchecked Sendable {
    
    var didRegisterWithDeviceInfo: DeviceInfo?
    func register(
        _ userId: String, fcmToken: String, deviceInfo: DeviceInfo
    ) async throws {
        self.didRegisterWithDeviceInfo = deviceInfo
    }
    
    func unregister(_ userId: String) async throws { }
}
