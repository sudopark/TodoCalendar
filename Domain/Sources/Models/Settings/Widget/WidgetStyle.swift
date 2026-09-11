//
//  WidgetStyle.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


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

    init()
}


// MARK: - WidgetStyle

public struct WidgetStyle<S: WidgetStyleSetting>: Sendable, Equatable {

    public let id: WidgetStyleId
    public let setting: S

    public init(id: WidgetStyleId, setting: S) {
        self.id = id
        self.setting = setting
    }
}
