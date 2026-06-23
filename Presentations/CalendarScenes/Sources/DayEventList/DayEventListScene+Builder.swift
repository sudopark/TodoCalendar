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


// MARK: - DayEventListScene Interactable & Listenable

protocol DayEventListSceneInteractor: AnyObject {

    func selectedDayChanaged(
        _ newDay: CurrentSelectDayModel,
        and eventThatDay: [any CalendarEvent]
    )
}

protocol DayEventListSceneListener: AnyObject {

    // 진입 버튼 재진입 등 command 결과 시트 표시 요청을 상위(단일 Calendar)로 위임
    func dayEventListDidRequestShowAICommand()
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
