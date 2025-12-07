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
        try await usecase.register(fcmToken: "token")
        
        // then
        #expect(self.spyRepository.didRegisterWithDeviceInfo?.deviceModel == "model")
    }
}


private final class StubRepository: UserNotificationRepository, @unchecked Sendable {
    
    var didRegisterWithDeviceInfo: DeviceInfo?
    func register(
        fcmToken: String, deviceInfo: DeviceInfo
    ) async throws {
        self.didRegisterWithDeviceInfo = deviceInfo
    }
    
    func unregister() async throws { }
}
