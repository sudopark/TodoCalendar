//
//  DefaultEventTagColorSetting.swift
//  Domain
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct DefaultEventTagColorSetting: Equatable, Sendable {
    public let holiday: String
    public let `default`: String
    
    public static let `default`: DefaultEventTagColorSetting = .init(
        holiday: "#D6236A", default: "#088CDA"
    )
    
    public init(holiday: String, `default`: String) {
        self.holiday = holiday
        self.default = `default`
    }
    
    public func update(_ params: EditDefaultEventTagColorParams) -> DefaultEventTagColorSetting {
        return DefaultEventTagColorSetting(
            holiday: params.newHolidayTagColor ?? self.holiday,
            default: params.newDefaultTagColor ?? self.default
        )
    }
}

public struct EditDefaultEventTagColorParams {
    public var newHolidayTagColor: String?
    public var newDefaultTagColor: String?
    public init() { }
    
    public var isValid: Bool {
        return self.newHolidayTagColor != nil
            || self.newDefaultTagColor != nil
    }
}
