//
//  WidgetStyleUsecase.swift
//  Domain
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public protocol WidgetStyleUsecase: Sendable {

    func refreshStyles(of variant: WidgetVariant)

    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never>

    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle]

    func updateStyle(_ style: WidgetStyle)

    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId

    func removeStyle(_ id: WidgetStyleId)
}


public final class WidgetStyleUsecaseImple: WidgetStyleUsecase {

    private let styleRepository: any WidgetStyleRepository
    private let sharedDataStore: SharedDataStore

    public init(
        styleRepository: any WidgetStyleRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.styleRepository = styleRepository
        self.sharedDataStore = sharedDataStore
    }

    private func shareKey(_ variant: WidgetVariant) -> String {
        return "\(ShareDataKeys.widgetStyles.rawValue):\(variant.rawValue)"
    }
}


// MARK: - 조회·갱신

extension WidgetStyleUsecaseImple {

    public func refreshStyles(of variant: WidgetVariant) {
        self.shareLatestStyles(of: variant)
    }

    public func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never> {

        return self.sharedDataStore
            .observe([WidgetStyle].self, key: self.shareKey(variant))
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    /// 저장소는 저장된 스타일만 주지만 화면은 기본 스타일을 항상 요구한다.
    public func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {

        guard let initialSetting = variant.initialSetting else { return [] }
        let savedStyles = self.styleRepository.loadStyles(of: variant)
        let defaultStyle = savedStyles.first { $0.id.style == .default }
            ?? WidgetStyle(
                id: .init(variant: variant, style: .default),
                name: nil,
                setting: initialSetting
            )
        let customStyles = savedStyles.filter { $0.id.style != .default }
        return [defaultStyle] + customStyles
    }

    /// 변형이 쓰는 payload 타입이 아니면 저장하지 않는다 — 다른 변형의 설정이 이 좌표를 덮는다.
    public func updateStyle(_ style: WidgetStyle) {
        guard style.id.variant.isOwnSetting(style.setting) else { return }
        self.styleRepository.updateStyle(style.withNormalizedName())
        self.shareLatestStyles(of: style.id.variant)
    }

    private func shareLatestStyles(of variant: WidgetVariant) {
        let latestStyles = self.loadStyles(of: variant)
        self.sharedDataStore.put(
            [WidgetStyle].self, key: self.shareKey(variant), latestStyles
        )
    }
}


// MARK: - 좌표 발급·삭제

extension WidgetStyleUsecaseImple {

    /// 좌표만 내주고 저장하지 않는다 — 새 스타일은 화면이 저장을 요청할 때까지 초안으로 남는다.
    public func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        return WidgetStyleId(variant: variant, style: .custom(id: UUID().uuidString))
    }

    /// 기본 스타일은 값이 없으면 조회가 코드 기본값으로 보충하는 자리라 지우는 것 자체가 성립하지 않는다.
    public func removeStyle(_ id: WidgetStyleId) {
        guard id.style != .default else { return }
        self.styleRepository.removeStyle(id)
        self.shareLatestStyles(of: id.variant)
    }
}


// MARK: - 이름 정규화

private extension WidgetStyle {

    func withNormalizedName() -> WidgetStyle {
        return WidgetStyle(
            id: self.id,
            name: self.name?.trimmingCharacters(in: .whitespacesAndNewlines).emptyAsNil(),
            setting: self.setting
        )
    }
}
