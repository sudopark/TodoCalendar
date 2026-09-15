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

    public init(variant: WidgetVariant, style: Style) {
        self.variant = variant
        self.style = style
    }
}


// MARK: - WidgetStyleSetting

public protocol WidgetStyleSetting: Codable, Sendable, Equatable {

    /// 저장값이 없거나 항목이 비었을 때 채워 넣을 값 — 스타일 좌표의 `.default` 와 다른 층이다.
    static var initial: Self { get }
}


// MARK: - WidgetStyle

public struct WidgetStyle<S: WidgetStyleSetting>: Sendable, Equatable {

    public let id: WidgetStyleId
    public var name: String?
    public var setting: S

    public init(id: WidgetStyleId, name: String?, setting: S) {
        self.id = id
        self.name = name
        self.setting = setting
    }
}


// MARK: - 표시 이름

extension WidgetStyle {

    public var displayName: String {
        switch self.id.style {
        case .default: return "widget.style::default".localized()
        case .custom: return self.name ?? "widget.style::custom::unnamed".localized()
        }
    }
}
