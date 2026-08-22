//
//  LiveActivityActionModel.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions


public struct LiveActivityActionModel: Equatable, Sendable {

    public let isRegistered: Bool

    public var itemText: String {
        return self.isRegistered
            ? "calendar::event::more_action:live_activity:unregister:item_name".localized()
            : "calendar::event::more_action:live_activity:register:item_name".localized()
    }

    public init(isRegistered: Bool) {
        self.isRegistered = isRegistered
    }
}
