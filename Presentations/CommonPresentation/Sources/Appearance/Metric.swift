//
//  Metric.swift
//  CommonPresentation
//
//  Created by sudo.park on 2026/07/09.
//

import CoreGraphics


// MARK: - Metric

// 룩앤필 메트릭 토큰 — 테마·사용자 설정과 무관한 고정값이라 ViewAppearance 주입 대상이 아님
public enum Metric {

    public enum Radius {
        /// 태그 칩, 작은 뱃지
        public static let chip: CGFloat = 4
        /// 카드, 버튼
        public static let regular: CGFloat = 8
        /// 큰 카드, 팝업
        public static let large: CGFloat = 12
        /// 바텀시트, 모달
        public static let sheet: CGFloat = 16
    }

    public enum Spacing {
        /// 밀착 텍스트·아이콘 간격
        public static let xxsmall: CGFloat = 2
        public static let xsmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let regular: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 20
        /// 계층 들여쓰기 (leading)
        public static let indent: CGFloat = 32
    }
}
