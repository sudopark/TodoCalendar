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


final class SingleMonthViewController: UIHostingController<DummyView>, SingleMonthScene {
    
    private let viewModel: SingleMonthViewModel
    var interactor: SingleMonthSceneInteractor? {
        return self.viewModel
    }
    init(viewModel: SingleMonthViewModel) {
        self.viewModel = viewModel
        
        super.init(rootView: DummyView())
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


struct DummyView: View {
        
    var body: some View {
        Text("hello world")
    }
}
