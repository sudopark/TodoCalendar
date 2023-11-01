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
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: EmptyInteractor?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = EventDetailContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        .eventHandler(\.onAppear, viewModel.prepare)
        .eventHandler(\.nameEntered, viewModel.enter(name:))
        .eventHandler(\.toggleIsTodo, viewModel.toggleIsTodo)
        .eventHandler(\.selectStartTime, viewModel.selectStartTime(_:))
        .eventHandler(\.selectEndTime, viewModel.selectEndtime(_:))
        .eventHandler(\.removeTime,  viewModel.removeTime)
        .eventHandler(\.removeEventEndTime, viewModel.removeEventEndTime)
        .eventHandler(\.toggleIsAllDay, viewModel.toggleIsAllDay)
        .eventHandler(\.selectRepeatOption, viewModel.selectRepeatOption)
        .eventHandler(\.selectTag, viewModel.selectEventTag)
//        .eventHandler(\.selectPlace, TODO)
        .eventHandler(\.enterUrl, viewModel.enter(url:))
        .eventHandler(\.enterMemo, viewModel.enter(memo:))
        .eventHandler(\.save, viewModel.save)
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
