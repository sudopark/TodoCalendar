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
import Scenes
import CommonPresentation


// MARK: - AppearanceSettingViewController

final class AppearanceSettingViewController: UIHostingController<AppearanceSettingContainerView>, AppearanceSettingScene {
    
    private let viewModel: any AppearanceSettingViewModel
    private let calendarSectionViewModel: any CalendarSectionViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any AppearanceSettingSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any AppearanceSettingViewModel,
        calendarSectionViewModel: any CalendarSectionViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.calendarSectionViewModel = calendarSectionViewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = AppearanceSettingViewEventHandler()
        
        let containerView = AppearanceSettingContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel, calendarSectionViewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
