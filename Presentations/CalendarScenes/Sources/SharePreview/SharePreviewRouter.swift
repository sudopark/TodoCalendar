//
//  SharePreviewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Scenes


// MARK: - Routing

protocol SharePreviewRouting: Routing, Sendable {
    func showShareSheet(text: String)
}


// MARK: - Router

final class SharePreviewRouter: BaseRouterImple, SharePreviewRouting, @unchecked Sendable { }
