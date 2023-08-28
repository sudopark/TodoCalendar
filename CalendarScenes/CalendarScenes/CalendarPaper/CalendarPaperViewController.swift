//
//  
//  CalendarPaperViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Combine
import Scenes
import CommonPresentation


// MARK: - CalendarPaperViewController

final class CalendarPaperViewController: UIViewController, CalendarPaperScene {
    
    private let viewModel: CalendarPaperViewModel
    private let viewAppearance: ViewAppearance
    
    private var cancellables: Set<AnyCancellable> = []
    
    var interactor: CalendarPaperSceneInteractor? { self.viewModel }
    
    init(
        viewModel: CalendarPaperViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        super.loadView()
        self.setupLayout()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.bind()
    }
}

// MARK: - bind

extension CalendarPaperViewController {
    
    private func bind() {
     
        self.viewAppearance.didUpdated
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] pair in
                self?.setupStyling(pair.0, pair.1)
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - setup presenting

extension CalendarPaperViewController {
    
    
    private func setupLayout() {
        
    }
    
    private func setupStyling(
        _ fontSet: FontSet, _ colorSet: ColorSet
    ) {
        self.view.backgroundColor = colorSet.dayBackground
    }
}
