//
//  PaywallRouter.swift
//  BillingScenes
//
//  Created by sudo.park on 8/3/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - PaywallRouting

protocol PaywallRouting: Routing, Sendable, AnyObject {

    func showManageSubscriptions(_ dismissed: @escaping @Sendable () -> Void)
}


// MARK: - PaywallRouter

final class PaywallRouter: BaseRouterImple, PaywallRouting, @unchecked Sendable {

    private let showManageSubscriptionsSheet: @MainActor @Sendable (UIWindowScene) async throws -> Void

    init(
        showManageSubscriptionsSheet: @escaping @MainActor @Sendable (UIWindowScene) async throws -> Void
    ) {
        self.showManageSubscriptionsSheet = showManageSubscriptionsSheet
        super.init()
    }

    func showManageSubscriptions(_ dismissed: @escaping @Sendable () -> Void) {
        Task { @MainActor in
            // 시트는 씬에 붙어야 뜬다 — 화면이 내려간 뒤 도달하면 붙일 창이 없다
            guard let windowScene = self.scene?.view.window?.windowScene else { return }
            do {
                try await self.showManageSubscriptionsSheet(windowScene)
                dismissed()
            } catch {
                self.showError(error)
            }
        }
    }
}
