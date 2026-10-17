//
//  
//  DayEventListScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import CalendarPresentation


// MARK: - DayEventListScene Interactable & Listenable

protocol DayEventListSceneInteractor: AnyObject {

    func selectedDayChanaged(
        _ newDay: CurrentSelectDayModel,
        and eventThatDay: [any CalendarEvent]
    )
    func selectedDayIsToday(_ isToday: Bool)
}

protocol DayEventListSceneListener: AnyObject {

    func dayEventListDidRequestShowAICommand()
    func dayEventListDidRequestReturnToToday()
}

// MARK: - DayEventListScene

protocol DayEventListScene: Scene where Interactor == any DayEventListSceneInteractor
{
    
}


// MARK: - Builder + DependencyInjector Extension

struct DayEventListSceneComponent {
    let viewModel: any DayEventListViewModel
    let router: any DayEventListRouting
}

protocol DayEventListSceneBuiler: AnyObject {
    
    func makeSceneComponent() -> DayEventListSceneComponent
}
