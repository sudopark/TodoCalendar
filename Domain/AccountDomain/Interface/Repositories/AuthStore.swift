//
//  AuthStore.swift
//  AccountDomainInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AuthStore: Sendable {
    
    func loadCurrentAuth() -> Auth?
    func saveAuth(_ auth: Auth)
    func removeAuth()
}
