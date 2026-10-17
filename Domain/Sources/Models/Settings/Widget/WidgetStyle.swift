//
//  WidgetStyle.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions


// MARK: - WidgetStyleId

/// 한 variant 가 기본 스타일 하나와 커스텀 스타일 N 개를 갖는다.
public struct WidgetStyleId: Hashable, Sendable {

    public enum Style: Hashable, Sendable {
        case `default`
        case custom(id: String)
    }

    public let variant: WidgetVariant
    public let style: Style

    /// 스타일을 공유하는 변형군은 대표 변형 좌표 하나만 갖는다 — 좌표를 만드는 자리가 여기 하나다.
    public init(variant: WidgetVariant, style: Style) {
        self.variant = variant.styleVariant
        self.style = style
    }
}


// MARK: - WidgetStyleSetting

public protocol WidgetStyleSetting: Codable, Sendable, Equatable {

    /// 저장값이 없거나 항목이 비었을 때 채워 넣을 값 — 스타일 좌표의 `.default` 와 다른 층이다.
    static var initial: Self { get }
}


extension WidgetStyleSetting {

    /// 존재 타입끼리는 == 가 안 걸린다 — Self 가 구체 타입인 이 자리에서만 열린다.
    public func isSame(_ other: any WidgetStyleSetting) -> Bool {
        return (other as? Self) == self
    }
}


// MARK: - WidgetStyle

/// 화면은 어느 변형인지를 런타임에 알아서 payload 타입을 컴파일 타임에 못 박을 수 없다.
public struct WidgetStyle: Sendable {

    public let id: WidgetStyleId
    public var name: String?
    public var setting: any WidgetStyleSetting

    /// nil 이면 전역 배경색을 따른다.
    public var background: WidgetAppearanceSettings.Background?

    public var photo: WidgetStylePhoto?

    public init(
        id: WidgetStyleId,
        name: String?,
        setting: any WidgetStyleSetting,
        background: WidgetAppearanceSettings.Background? = nil,
        photo: WidgetStylePhoto? = nil
    ) {
        self.id = id
        self.name = name
        self.setting = setting
        self.background = background
        self.photo = photo
    }
}


// MARK: - 표시 이름·동치

extension WidgetStyle {

    public var displayName: String {
        switch self.id.style {
        case .default: return "widget.style::default".localized()
        case .custom: return self.name ?? "widget.style::custom::unnamed".localized()
        }
    }

    public func isSame(_ other: WidgetStyle?) -> Bool {
        guard let other else { return false }
        return self.id == other.id
            && self.name == other.name
            && self.background == other.background
            && self.photo == other.photo
            && self.setting.isSame(other.setting)
    }
}
