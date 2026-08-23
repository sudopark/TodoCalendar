//
//  AdRepository.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AdRepository: Sendable {

    func loadFullScreenAdExposureRecords() -> [FullScreenAdExposureRecord]
    func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord)
}
