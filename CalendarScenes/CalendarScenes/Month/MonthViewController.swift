//
//  MonthViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import SwiftUI
import Domain
import Scenes
import CommonPresentation


final class MonthViewController: UIHostingController<MonthContainerView>, MonthScene {
    
    private let viewModel: MonthViewModel
    private let viewAppearance: ViewAppearance
    var interactor: MonthSceneInteractor? {
        return self.viewModel
    }
    init(
        viewModel: MonthViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let monthView = MonthContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        .eventHandler(\.daySelected, viewModel.select(_:))
        super.init(rootView: monthView)
        
        self.view.backgroundColor = self.viewAppearance.colorSet.dayBackground
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
