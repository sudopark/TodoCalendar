//
//  UserEventExistenceRepository.swift
//  Domain
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol UserEventExistenceRepository: Sendable {

    func fetchHasAnyEvent() async throws -> Bool
}
