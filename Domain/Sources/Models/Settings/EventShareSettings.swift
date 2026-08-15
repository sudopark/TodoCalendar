//
//  EventShareSettings.swift
//  Domain
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


// MARK: - EventShareSettings

public struct EventShareSettings: Sendable, Equatable {

    public var includeTagName: Bool = false

    public init() { }

    public func update(_ params: EditEventShareSettingsParams) -> EventShareSettings {
        return self
            |> \.includeTagName .~ (params.includeTagName ?? self.includeTagName)
    }
}


// MARK: - EditEventShareSettingsParams

public struct EditEventShareSettingsParams: Sendable, Equatable {

    public var includeTagName: Bool?

    public init() { }

    public var isValid: Bool {
        return self.includeTagName != nil
    }
}
