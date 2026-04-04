//
//  AppleCalendarPermissionFailReason.swift
//  Domain
//
//  Created by sudo.park on 4/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum AppleCalendarPermissionFailReason: Error, Sendable {
    case denied     // 사용자가 명시적으로 거부 → 설정 이동 유도
    case restricted // 기기 정책으로 제한 → 지원 불가 안내
    case writeOnly  // writeOnly 상태에서 fullAccess 업그레이드 실패 → 설정 이동 유도
}
