//
//  TrackingGuideHostingViewController.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import CommonPresentation


final class TrackingGuideHostingViewController: UIHostingController<TrackingGuideView> {

    init(
        appearance: ViewAppearance,
        onContinue: @escaping @Sendable () -> Void,
        onDecline: @escaping @Sendable () -> Void
    ) {
        let guideView = TrackingGuideView(appearance: appearance)
            .eventHandler(\.onContinue, onContinue)
            .eventHandler(\.onDecline, onDecline)
        super.init(rootView: guideView)
        self.view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
