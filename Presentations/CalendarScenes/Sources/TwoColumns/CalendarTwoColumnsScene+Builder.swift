//
//  CalendarTwoColumnsScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import Domain


// MARK: - CalendarTwoColumnsScene Interactable & Listenable

protocol CalendarTwoColumnsSceneInteractor: Sendable, AnyObject, ContinuousMonthsSceneListener, DayEventListSceneListener {

    func changeFocusedMonth(to month: CalendarMonth)
    func selectDay(_ day: CalendarDay)
    func selectedDayIsToday(_ isToday: Bool)
    func scrollToVoiceInput()
}

protocol CalendarTwoColumnsSceneListener: AnyObject {

    func calendarTwoColumns(didScrollTo month: CalendarMonth)
    func calendarTwoColumns(didSelect day: CalendarDay)
    func calendarTwoColumnsDidRequestShowAICommand()
    func calendarTwoColumnsDidRequestReturnToToday()
}

// MARK: - CalendarTwoColumnsScene

protocol CalendarTwoColumnsScene: Scene where Interactor == any CalendarTwoColumnsSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol CalendarTwoColumnsSceneBuilder: AnyObject {

    @MainActor
    func makeTwoColumnsScene(
        initialMonth: CalendarMonth,
        listener: (any CalendarTwoColumnsSceneListener)?
    ) -> any CalendarTwoColumnsScene
}
