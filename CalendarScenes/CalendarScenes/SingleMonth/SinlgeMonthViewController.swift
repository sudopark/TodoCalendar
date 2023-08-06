//
//  SinlgeMonthViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import SwiftUI
import Domain
import Scenes
import CommonPresentation


final class SingleMonthViewController: UIHostingController<SingleMonthContainerView>, SingleMonthScene {
    
    private let viewModel: SingleMonthViewModel
    private let viewAppearance: ViewAppearance
    var interactor: SingleMonthSceneInteractor? {
        return self.viewModel
    }
    init(
        viewModel: SingleMonthViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let monthView = SingleMonthContainerView(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        super.init(rootView: monthView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
