//
//  
//  EventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventDetailViewController

final class EventDetailViewController: UIHostingController<EventDetailContainerView>, EventDetailScene {
    
    private let viewModel: any EventDetailViewModel
    private let inputViewModel: any EventDetailInputViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: EmptyInteractor?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventDetailViewModel,
        inputViewModel: any EventDetailInputViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.inputViewModel = inputViewModel
        self.viewAppearance = viewAppearance
        
        let containerView = EventDetailContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel, inputViewModel) })
        .eventHandler(\.onAppear) {
            inputViewModel.setup()
            viewModel.prepare()
        }
        .eventHandler(\.nameEntered, inputViewModel.enter(name:))
        .eventHandler(\.toggleIsTodo, viewModel.toggleIsTodo)
        .eventHandler(\.selectStartTime, inputViewModel.selectStartTime(_:))
        .eventHandler(\.selectEndTime, inputViewModel.selectEndtime(_:))
        .eventHandler(\.removeTime,  inputViewModel.removeTime)
        .eventHandler(\.removeEventEndTime, inputViewModel.removeEventEndTime)
        .eventHandler(\.toggleIsAllDay, inputViewModel.toggleIsAllDay)
        .eventHandler(\.selectRepeatOption, inputViewModel.selectRepeatOption)
        .eventHandler(\.selectTag, inputViewModel.selectEventTag)
        .eventHandler(\.selectNotificationOption, inputViewModel.selectNotificationTime)
//        .eventHandler(\.selectPlace, TODO)
        .eventHandler(\.enterUrl, inputViewModel.enter(url:))
        .eventHandler(\.enterMemo, inputViewModel.enter(memo:))
        .eventHandler(\.save, viewModel.save)
        .eventHandler(\.doMoreAction, viewModel.handleMoreAction(_:))
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
