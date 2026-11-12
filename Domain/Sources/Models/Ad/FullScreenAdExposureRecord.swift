//
//  FullScreenAdExposureRecord.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct FullScreenAdExposureRecord: Equatable, Sendable {

    public let lastExposeDate: Date
    public let countOfDay: Int

    public init(lastExposeDate: Date, countOfDay: Int) {
        self.lastExposeDate = lastExposeDate
        self.countOfDay = countOfDay
    }
}
