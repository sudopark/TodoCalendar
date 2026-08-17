//
//  AppleCalendarEventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol AppleCalendarEventDetailRouting: Routing, Sendable {

    func routeToAppleCalendarApp(at interval: TimeInterval)

    func routeToEventRepeatOptionSelect(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    )
}

// MARK: - Router

final class AppleCalendarEventDetailRouter: BaseRouterImple, AppleCalendarEventDetailRouting, @unchecked Sendable {

    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler

    init(selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
    }
}


extension AppleCalendarEventDetailRouter {

    private var currentScene: (any AppleCalendarEventDetailScene)? {
        self.scene as? (any AppleCalendarEventDetailScene)
    }

    func routeToAppleCalendarApp(at interval: TimeInterval) {
        // calshow: scheme uses seconds since 2001-01-01 (Core Data reference date)
        let referenceInterval = interval - 978307200
        guard let url = URL(string: "calshow:\(referenceInterval)") else { return }
        UIApplication.shared.open(url)
    }

    func routeToEventRepeatOptionSelect(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        Task { @MainActor in
            let next = self.selectRepeatOptionSceneBuilder.makeSelectEventRepeatOptionScene(
                selectTime: selectTime,
                previousSelected: repeating,
                rruleRepresentableOnly: true,
                listener: listener
            )
            self.scene?.present(next, animated: true)
        }
    }
}
