//
//  AuthRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public protocol AuthRepository: Sendable {
    
    func loadLatestLoginUserId() async throws -> String?
}
