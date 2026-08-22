//
//  FeatureFlag.swift
//  Domain
//
//  Created by sudo.park on 2/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public final class FeatureFlag: @unchecked Sendable {
    
    public enum Flags: Sendable {
        case reservedFlag
        /// D-day 위젯(#741) — 배포 보류 중. 켜면 일정 상세에 후보 등록 메뉴가 다시 노출된다.
        /// 위젯 갤러리 노출은 `TodoCalendarWidgetBundle`에서 별도로 막혀 있다.
        case ddayWidget
        /// Billing paywall(#739) — 배포 보류 중. ASC 상품 메타데이터·서버 productId 정합이
        /// 끝나기 전엔 진입점(한도 초과 화면 · 설정)을 닫아둔다.
        case billingPaywall
    }
    
    private var enableFlags: Set<Flags> = []
    
    private static let shared: FeatureFlag = .init()
    private init() { }
}


extension FeatureFlag {
    
    public static func enable(_ flag: Flags) {
        FeatureFlag.shared.enableFlags.insert(flag)
    }
    
    public static func disable(_ flag: Flags) {
        FeatureFlag.shared.enableFlags.remove(flag)
    }
    
    public static func isEnable(_ flag: Flags) -> Bool {
        return FeatureFlag.shared.enableFlags.contains(flag)
    }
}
