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

    /// spacing 정규화 토큰 — 값의 단일 소스. View.padding(_:spacing:)이 대표값만 받도록 강제한다.
    public enum SpacingToken {
        /// 밀착 텍스트·아이콘 간격
        case xxsmall
        case xsmall
        case small
        case regular
        case large
        case xlarge
        /// 계층 들여쓰기 (leading)
        case indent

        public var value: CGFloat {
            switch self {
            case .xxsmall: return 2
            case .xsmall: return 4
            case .small: return 8
            case .regular: return 12
            case .large: return 16
            case .xlarge: return 20
            case .indent: return 32
            }
        }
    }

    /// SpacingToken 값의 CGFloat 파생 상수 — stack spacing: 파라미터 등 CGFloat 자리 전용
    public enum Spacing {
        public static let xxsmall: CGFloat = SpacingToken.xxsmall.value
        public static let xsmall: CGFloat = SpacingToken.xsmall.value
        public static let small: CGFloat = SpacingToken.small.value
        public static let regular: CGFloat = SpacingToken.regular.value
        public static let large: CGFloat = SpacingToken.large.value
        public static let xlarge: CGFloat = SpacingToken.xlarge.value
        public static let indent: CGFloat = SpacingToken.indent.value
    }
}
