//
//  
//  CalendarPaperViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import SwiftUI
import UIKit
import Combine
import Scenes
import CommonPresentation


// MARK: - CalendarPaperViewController

final class CalendarPaperViewController: UIHostingController<CalenarPaperContainerView>, CalendarPaperScene {
    
    private let viewModel: any CalendarPaperViewModel
    private let viewAppearance: ViewAppearance
    
    private var cancellables: Set<AnyCancellable> = []
    
    @MainActor
    var interactor: (any CalendarPaperSceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any CalendarPaperViewModel,
        monthViewModel: any MonthViewModel,
        eventListViewModel: any DayEventListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let monthViewEventHandler = MonthViewEventHandler()
        monthViewEventHandler.bind(monthViewModel)
        let monthView = MonthContainerView(
            viewAppearance: viewAppearance, eventHandler: monthViewEventHandler
        )
        .eventHandler(\.stateBinding, { $0.bind(monthViewModel) })
        
        let eventListViewEventHandler = DayEventListViewEventHandler()
        eventListViewEventHandler.bind(eventListViewModel)
        let eventListView = DayEventListContainerView(
            viewAppearance: viewAppearance, eventHandler: eventListViewEventHandler
        )
        .eventHandler(\.stateBinding, { $0.bind(eventListViewModel) })
        
        let eventHandler = CalenarPaperViewEventHandelr()
        eventHandler.bind(viewModel)
        let containerView = CalenarPaperContainerView(
            monthView: monthView,
            eventListView: eventListView,
            viewAppearance: viewAppearance,
            eventHandler: eventHandler
        )
        super.init(rootView: containerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
