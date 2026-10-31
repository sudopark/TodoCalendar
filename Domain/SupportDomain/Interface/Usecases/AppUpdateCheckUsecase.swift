//
//  AppUpdateCheckUsecase.swift
//  SupportDomainInterface
//

import Foundation
import Combine
import CombineExt
import AsyncFlatMap
import Extensions


// MARK: - AppUpdateCheckUsecase

public protocol AppUpdateCheckUsecase: Sendable {
    func checkUpdateIsNeed()
    var updateRequirement: AnyPublisher<AppUpdateRequirement, Never> { get }
    var isUpdateAvailable: AnyPublisher<Bool, Never> { get }
}
