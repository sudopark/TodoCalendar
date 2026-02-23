//
//  EventListSceneBuilderImple.swift
//  EventListScenes
//
//  Created by sudo.park on 5/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import CommonPresentation
import Scenes


public final class EventListSceneBuilerImple: EventListSceneBuiler {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventDetailSceneBuilder: any EventDetailSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
    }
}

extension EventListSceneBuilerImple {
    
    @MainActor
    public func makeDoneTodoEventListScene() -> any DoneTodoEventListScene {
        let builder = DoneTodoEventListSceneBuilerImple(
            usecaseFactory: usecaseFactory,
            viewAppearance: viewAppearance,
            eventDetailSceneBuilder: eventDetailSceneBuilder
        )
        return builder.makeDoneTodoEventListScene()
    }
}
