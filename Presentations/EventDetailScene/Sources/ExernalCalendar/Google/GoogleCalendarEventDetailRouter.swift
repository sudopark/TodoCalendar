//
//
//  GoogleCalendarEventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol GoogleCalendarEventDetailRouting: Routing, Sendable {

    func routeToEventRepeatOptionSelect(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    )
}

// MARK: - Router

final class GoogleCalendarEventDetailRouter: BaseRouterImple, GoogleCalendarEventDetailRouting, @unchecked Sendable {

    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler

    init(selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
    }
}


extension GoogleCalendarEventDetailRouter {

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
