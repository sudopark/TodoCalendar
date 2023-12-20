//
//  
//  HolidayListViewController.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - HolidayListViewController

final class HolidayListViewController: UIHostingController<HolidayListContainerView>, HolidayListScene {
    
    private let viewModel: any HolidayListViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any HolidayListSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any HolidayListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = HolidayListViewEventHandler()
        eventHandlers.onAppear = viewModel.prepare
        eventHandlers.selectCountry = viewModel.selectCountry
        eventHandlers.close = viewModel.close
        
        let containerView = HolidayListContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
