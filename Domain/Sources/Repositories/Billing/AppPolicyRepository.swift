//
//  AppPolicyRepository.swift
//  Domain
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AppPolicyRepository: Sendable {

    func loadPolicy() -> AppPolicy?
    func refreshPolicy() async throws
}
