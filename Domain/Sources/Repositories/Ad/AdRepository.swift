//
//  AdRepository.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AdRepository: Sendable {

    func loadFullScreenAdExposureRecord() -> FullScreenAdExposureRecord?
    func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord)

    func loadEventSavedCountForFullScreenAd() -> Int
    func updateEventSavedCountForFullScreenAd(_ count: Int)

    func loadHasShownTrackingGuide() -> Bool
    func markTrackingGuideShown()
}
