//
//  AppRepository.swift
//  SupportDomainInterface
//

import Foundation

public protocol AppRepository: Sendable {
    func loadUpdateInfo() async throws -> AppUpdateInfo
}
