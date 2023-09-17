//
//  
//  DayEventListViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - DayEventListViewController

final class DayEventListViewController: UIHostingController<DayEventListContainerView>, DayEventListScene {
    
    private let viewModel: any DayEventListViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any DayEventListSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any DayEventListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = DayEventListContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        .eventHandler(\.requestDoneTodo, viewModel.doneTodo(_:))
        .eventHandler(\.requestAddNewEventWhetherUsingTemplate) { isUsingTemplate in
            isUsingTemplate
            ? viewModel.makeEventByTemplate()
            : viewModel.makeEvent()
        }
        .eventHandler(\.addNewTodoQuickly, viewModel.addNewTodoQuickly(withName:))
        .eventHandler(\.makeNewTodoWithGivenNameAndDetails, viewModel.makeTodoEvent(with:))
        super.init(rootView: containerView)
        self.sizingOptions = [.intrinsicContentSize]
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.invalidateIntrinsicContentSize()
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
