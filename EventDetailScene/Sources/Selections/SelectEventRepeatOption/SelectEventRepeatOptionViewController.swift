//
//  
//  SelectEventRepeatOptionViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SelectEventRepeatOptionViewController

final class SelectEventRepeatOptionViewController: UIHostingController<SelectEventRepeatOptionContainerView>, SelectEventRepeatOptionScene {
    
    private let viewModel: any SelectEventRepeatOptionViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SelectEventRepeatOptionSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SelectEventRepeatOptionViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandler = SelectEventRepeatOptionViewEventHandlers()
        eventHandler.close = viewModel.close
        eventHandler.itemSelect = viewModel.selectOption(_:)
        eventHandler.endTimeSelect = viewModel.selectRepeatEndDate(_:)
        eventHandler.toggleHasEndTime = viewModel.toggleHasRepeatEnd(isOn:)
        eventHandler.onAppear = viewModel.prepare
        let containerView = SelectEventRepeatOptionContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandler
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
