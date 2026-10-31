//
//  WidgetStyleFetchUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SettingDomainInterface


// MARK: - WidgetStyleFetchUsecase

protocol WidgetStyleFetchUsecase: Sendable {

    func fetchStyle(of variant: WidgetVariant, selected style: WidgetStyleId.Style) -> WidgetStyle?

    func fetchStyleCandidates(of variant: WidgetVariant) -> [WidgetStyle]
}


// MARK: - WidgetStyleFetchUsecaseImple

final class WidgetStyleFetchUsecaseImple: WidgetStyleFetchUsecase, @unchecked Sendable {

    private let styleRepository: any WidgetStyleRepository

    init(styleRepository: any WidgetStyleRepository) {
        self.styleRepository = styleRepository
    }
}


// MARK: - 조회

extension WidgetStyleFetchUsecaseImple {

    /// 고른 커스텀이 지워졌으면 기본 저장분으로 돌아간다
    func fetchStyle(
        of variant: WidgetVariant, selected style: WidgetStyleId.Style
    ) -> WidgetStyle? {
        let selected = self.styleRepository.loadStyle(for: .init(variant: variant, style: style))
        let fallback = style == .default
            ? nil
            : self.styleRepository.loadStyle(for: .init(variant: variant, style: .default))
        return selected ?? fallback
    }

    /// 후보는 기본 스타일을 맨 앞에 항상 둔다 — 꾸민 적 없는 기본은 초기 설정으로 세운다
    func fetchStyleCandidates(of variant: WidgetVariant) -> [WidgetStyle] {
        let styleVariant = variant.styleVariant
        guard let initialSetting = styleVariant.initialSetting else { return [] }
        let savedStyles = self.styleRepository.loadStyles(of: styleVariant)
        let savedDefault = savedStyles.first { $0.id.style == .default }
        let initialDefault = WidgetStyle(
            id: .init(variant: variant, style: .default), name: nil, setting: initialSetting
        )
        let customStyles = savedStyles.filter { $0.id.style != .default }
        return [savedDefault ?? initialDefault] + customStyles
    }
}
