//
//  AppRepository.swift
//  Domain
//

import Foundation

public protocol AppRepository: Sendable {
    func loadUpdateInfo() async throws -> AppUpdateInfo
}
