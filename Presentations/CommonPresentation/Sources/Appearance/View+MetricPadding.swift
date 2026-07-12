//
//  View+MetricPadding.swift
//  CommonPresentation
//
//  Created by sudo.park on 7/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


extension View {

    /// Metric 대표값만 허용하는 padding — 임의 CGFloat 대신 이 오버로드를 사용한다 (rules §8).
    /// `spacing:` 레이블로 시스템 `padding(_:_:)`과 시그니처가 분리된다.
    public func padding(_ edges: Edge.Set = .all, spacing: Metric.SpacingToken) -> some View {
        return self.padding(edges, spacing.value)
    }
}
