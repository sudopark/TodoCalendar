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
        /// AI Agent(#746) — 배포 보류 중. 켜면 캘린더 일별 리스트에 AI 진입 버튼이 노출되고
        /// 앱 시작 시 orchestration prepare(usage 로드·job 복원)가 재개된다.
        case aiAgent
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
