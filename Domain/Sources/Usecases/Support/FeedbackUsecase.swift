//
//  FeedbackUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Combine


public protocol FeedbackUsecase: Sendable {
 
    func postFeedback(_ message: FeedbackPostMessage) async throws
}

public protocol DeviceInfoFetchService: Sendable {
    @MainActor
    func fetchDeviceInfo() async -> DeviceInfo
}

public final class FeedbackUsecaseImple: FeedbackUsecase, @unchecked Sendable {
    
    private let accountUsecase: any AccountUsecase
    private let feedbackRepository: any FeedbackRepository
    private let deviceInfoFetchService: any DeviceInfoFetchService
    
    private let userId = CurrentValueSubject<String?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        accountUsecase: any AccountUsecase,
        feedbackRepository: any FeedbackRepository,
        deviceInfoFetchService: any DeviceInfoFetchService
    ) {
        self.accountUsecase = accountUsecase
        self.feedbackRepository = feedbackRepository
        self.deviceInfoFetchService = deviceInfoFetchService
        
        self.bindCurrentAccount()
    }
    
    private func bindCurrentAccount() {
        
        self.accountUsecase.currentAccountInfo
            .sink(receiveValue: { [weak self] account in
                self?.userId.send(account?.userId)
            })
            .store(in: &self.cancellables)
    }
}

extension FeedbackUsecaseImple {
    
    public func postFeedback(_ message: FeedbackPostMessage) async throws {
        
        let userId = self.userId.value
        let deviceInfo = await self.deviceInfoFetchService.fetchDeviceInfo()
        let params = FeedbackMakeParams(
            message.contactEmail, message.message
        )
        |> \.userId .~ userId
        |> \.osVersion .~ deviceInfo.osVersion
        |> \.appVersion .~ deviceInfo.appVersion
        |> \.deviceModel .~ deviceInfo.deviceModel
        |> \.isIOSAppOnMac .~ deviceInfo.isiOSAppOnMac
        
        try await self.feedbackRepository.postFeedback(params)
    }
}
