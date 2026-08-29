//
//  GoogleCalendarWriteScopeFailReason.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum GoogleCalendarWriteScopeFailReason: Error, Sendable {
    case notGranted // 조직 정책으로 write 가 막힌 계정
}
