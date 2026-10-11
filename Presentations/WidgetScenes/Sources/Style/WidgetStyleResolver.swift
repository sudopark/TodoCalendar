//
//  WidgetStyleResolver.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public struct WidgetCustomStyleLockedError: Error, Sendable {
    public init() { }
}


public struct WidgetStyleResolver: Sendable {

    private let styleRepository: any WidgetStyleRepository
    private let paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase

    public init(
        styleRepository: any WidgetStyleRepository,
        paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase
    ) {
        self.styleRepository = styleRepository
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
    }

    /// 지워진 커스텀은 잠그지 않고 기본 저장분으로 돌아간다
    public func resolveStyle(
        of variant: WidgetVariant, style: WidgetStyleId.Style, at now: Date
    ) throws -> WidgetStyle? {
        guard let selected = self.savedStyle(variant, style) else {
            return self.resolveDefaultStyle(of: variant)
        }
        guard style != .default,
              self.paidFeatureGateUsecase.canRenderCustomWidgetStyle(at: now) == false
        else { return selected }
        throw WidgetCustomStyleLockedError()
    }

    public func resolveDefaultStyle(of variant: WidgetVariant) -> WidgetStyle? {
        return self.savedStyle(variant, .default)
    }

    private func savedStyle(
        _ variant: WidgetVariant, _ style: WidgetStyleId.Style
    ) -> WidgetStyle? {
        return self.styleRepository.loadStyle(for: .init(variant: variant, style: style))
    }
}
