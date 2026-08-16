//
//  MobileAdService.swift
//  Domain
//
//  Created by sudo.park on 8/16/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol MobileAdService: Sendable {

    func prepare() async

    func loadRewardedAd(unitId: String) async throws
}
