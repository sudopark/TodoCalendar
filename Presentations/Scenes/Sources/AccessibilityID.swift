//
//  AccessibilityID.swift
//  Scenes
//
//  Created by sudo.park on 2026/09/08.
//

import Foundation


// MARK: - AccessibilityID

// 값 규약: <scene>.<component>[.<detail>] 소문자 점 구분
public enum AccessibilityID {
    
    public enum CalendarScene {
        // 주 데이터까지 채워져 그려진 그리드에만 걸린다 — 존재 자체가 렌더 완료 신호다
        public static let monthGrid = "calendar.month.grid"
    }
}
