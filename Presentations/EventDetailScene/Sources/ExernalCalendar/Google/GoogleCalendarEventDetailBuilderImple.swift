//
//  
//  GoogleCalendarEventDetailBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventDetailSceneBuilerImple

public final class GoogleCalendarEventDetailSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension GoogleCalendarEventDetailSceneBuilerImple: GoogleCalendarEventDetailSceneBuiler {
    
    @MainActor
    public func makeGoogleCalendarEventDetailScene(
        calendarId: String, eventId: String
    ) -> any GoogleCalendarEventDetailScene {
        
        let viewModel = GoogleCalendarEventDetailViewModelImple(
            calenadrId: calendarId, eventId: eventId,
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase()
        )
        
        let viewController = GoogleCalendarEventDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = GoogleCalendarEventDetailRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
