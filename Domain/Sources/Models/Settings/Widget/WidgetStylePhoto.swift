//
//  WidgetStylePhoto.swift
//  Domain
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct WidgetStylePhoto: Sendable, Equatable {

    public let id: String?
    public let original: URL
    public let rendering: URL

    public init(id: String?, original: URL, rendering: URL) {
        self.id = id
        self.original = original
        self.rendering = rendering
    }

    public var isDraft: Bool {
        return self.id == nil
    }
}
