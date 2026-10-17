//
//  RewardedAdResult.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum RewardedAdResult: Equatable, Sendable {
    case rewarded
    case fallbackFullScreenShown
    case dismissedBeforeReward
    case unavailable
}
