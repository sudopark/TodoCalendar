//
//  
//  AppearanceSettingViewController.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import SwiftUI
import Combine
import Domain
import Scenes
import CommonPresentation


// MARK: - AppearanceSettingViewController

final class AppearanceSettingViewController: UIHostingController<AppearanceSettingContainerView>, AppearanceSettingScene {
    
    private let viewModel: any AppearanceSettingViewModel
    private let calendarSectionViewModel: any CalendarSectionAppearnaceSettingViewModel
    private let eventOnCalednarSectionViewModel: any EventOnCalendarViewModel
    private let eventListAppearanceSettingViewModel: any EventListAppearnaceSettingViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any AppearanceSettingSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        initial setting: AppearanceSettings,
        viewModel: any AppearanceSettingViewModel,
        calendarSectionViewModel: any CalendarSectionAppearnaceSettingViewModel,
        eventOnCalednarSectionViewModel: any EventOnCalendarViewModel,
        eventListAppearanceSettingViewModel: any EventListAppearnaceSettingViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.calendarSectionViewModel = calendarSectionViewModel
        self.eventOnCalednarSectionViewModel = eventOnCalednarSectionViewModel
        self.eventListAppearanceSettingViewModel = eventListAppearanceSettingViewModel
        self.viewAppearance = viewAppearance
        
        let calendarSectionEventHandler = CalendarSectionAppearanceSettingViewEventHandler()
        calendarSectionEventHandler.weekStartDaySelected = calendarSectionViewModel.changeStartOfWeekDay(_:)
        calendarSectionEventHandler.changeColorTheme = calendarSectionViewModel.changeColorTheme
        calendarSectionEventHandler.toggleAccentDay = calendarSectionViewModel.toggleAccentDay(_:)
        calendarSectionEventHandler.toggleShowUnderline = calendarSectionViewModel.toggleIsShowUnderLineOnEventDay(_:)
        
        let eventOnCalendarEventHandler = EventOnCalendarViewEventHandler()
        eventOnCalendarEventHandler.increaseFontSize = eventOnCalednarSectionViewModel.increaseTextSize
        eventOnCalendarEventHandler.decreaseFontSize = eventOnCalednarSectionViewModel.decreaseTextSize
        eventOnCalendarEventHandler.toggleIsBold = eventOnCalednarSectionViewModel.toggleBoldText(_:)
        eventOnCalendarEventHandler.toggleShowEventTagColor = eventOnCalednarSectionViewModel.toggleShowEventTagColor(_:)
        
        let eventListSettingHandler = EventListAppearanceSettingViewEventHandler()
        eventListSettingHandler.increaseFontSize = eventListAppearanceSettingViewModel.increaseFontSize
        eventListSettingHandler.decreaseFontSize = eventListAppearanceSettingViewModel.decreaseFontSize
        eventListSettingHandler.toggleIsShowHolidayName = eventListAppearanceSettingViewModel.toggleShowHolidayName(_:)
        eventListSettingHandler.toggleShowLunarCalendarDate = eventListAppearanceSettingViewModel.toggleShowLunarCalendarDate(_:)
        eventListSettingHandler.toggleIs24HourFom = eventListAppearanceSettingViewModel.toggleIsShowTimeWith24HourForm(_:)
        
        let appearanceEventHandler = AppearanceSettingViewEventHandler()
        appearanceEventHandler.changeTimeZone = viewModel.routeToSelectTimezone
        appearanceEventHandler.toggleHapticFeedback = viewModel.toggleIsOnHapticFeedback(_:)
        appearanceEventHandler.toggleAnimationEffect = viewModel.toggleMinimizeAnimationEffect(_:)
        appearanceEventHandler.close = viewModel.close
        
        let containerView = AppearanceSettingContainerView(
            setting,
            viewAppearance: viewAppearance,
            calendarSectionEventHandler: calendarSectionEventHandler,
            eventOnCalendarSectionEventHandler: eventOnCalendarEventHandler,
            eventListSettingEventHandler: eventListSettingHandler,
            appearanceSettingEventHandler: appearanceEventHandler
        )
        .eventHandler(\.calendarSectionStateBinding) { $0.bind(calendarSectionViewModel) }
        .eventHandler(\.eventOnCalendarSectionStateBinding) { $0.bind(eventOnCalednarSectionViewModel) }
        .eventHandler(\.eventListSettingStateBinding) { $0.bind(eventListAppearanceSettingViewModel) }
        .eventHandler(\.appearanceSettingStateBinding) { $0.bind(viewModel) }
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
