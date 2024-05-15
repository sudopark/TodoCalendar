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
    
    public init(usecaseFactory: any UsecaseFactory, viewAppearance: ViewAppearance) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}

extension EventListSceneBuilerImple {
    
    @MainActor
    public func makeDoneTodoEventListScene() -> any DoneTodoEventListScene {
        let builder = DoneTodoEventListSceneBuilerImple(usecaseFactory: usecaseFactory, viewAppearance: viewAppearance)
        return builder.makeDoneTodoEventListScene()
    }
}
