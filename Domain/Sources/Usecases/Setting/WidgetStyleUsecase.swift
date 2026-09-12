//
//  WidgetStyleUsecase.swift
//  Domain
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol WidgetStyleUsecase: Sendable {

    func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>]

    func updateStyle<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId)
}


public final class WidgetStyleUsecaseImple: WidgetStyleUsecase {

    private let styleRepository: any WidgetStyleRepository

    public init(styleRepository: any WidgetStyleRepository) {
        self.styleRepository = styleRepository
    }
}


// MARK: - 조회·갱신

extension WidgetStyleUsecaseImple {

    /// 저장소는 저장된 스타일만 주지만 화면은 기본 스타일을 항상 요구한다.
    public func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>] {

        let savedStyles = self.styleRepository.loadStyles(type, of: variant)
        let defaultStyle = savedStyles.first { $0.id.style == .default }
            ?? WidgetStyle(id: .init(variant: variant, style: .default), setting: S())
        let customStyles = savedStyles.filter { $0.id.style != .default }
        return [defaultStyle] + customStyles
    }

    public func updateStyle<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId) {
        self.styleRepository.updateSetting(setting, for: id)
    }
}
