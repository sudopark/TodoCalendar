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
    
    private let scrollView = UIScrollView()
    private let contentContainerView = UIView()
    private let monthContainerView = UIView()
    private let eventListContainerView = UIView()
    
    private let viewModel: any CalendarPaperViewModel
    private let viewAppearance: ViewAppearance
    
    private var cancellables: Set<AnyCancellable> = []
    
    var interactor: (any CalendarPaperSceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any CalendarPaperViewModel,
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
        self.viewModel.prepare()
    }
    
    func addMonth(_ monthScene: any Scene) {
        self.addChild(monthScene)
        self.monthContainerView.addSubview(monthScene.view)
        monthScene.didMove(toParent: self)
        monthScene.view.autoLayout.active(with: monthContainerView) {
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
        monthScene.view.setContentCompressionResistancePriority(.required, for: .vertical)
        monthScene.view.sizeToFit()
    }
    
    func addDayEventList(_ eventListScene: any Scene) {
        self.addChild(eventListScene)
        self.eventListContainerView.addSubview(eventListScene.view)
        eventListScene.didMove(toParent: self)
        eventListScene.view.autoLayout.active(with: eventListContainerView) {
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
        eventListScene.view.sizeToFit()
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
        
        self.view.addSubview(scrollView)
        scrollView.autoLayout.active {
            $0.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor)
            $0.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
            $0.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        }
        
        scrollView.addSubview(contentContainerView)
        contentContainerView.autoLayout.active {
            $0.topAnchor.constraint(equalTo: self.scrollView.topAnchor)
            $0.leadingAnchor.constraint(equalTo: self.scrollView.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: self.scrollView.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: self.scrollView.bottomAnchor)
            $0.widthAnchor.constraint(equalTo: self.scrollView.widthAnchor)
            $0.heightAnchor.constraint(equalTo: self.scrollView.heightAnchor).setupPriority(.defaultLow)
        }

        contentContainerView.addSubview(monthContainerView)
        monthContainerView.autoLayout.active(with: contentContainerView) {
            $0.topAnchor.constraint(equalTo: $1.topAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
        }
        monthContainerView.setContentCompressionResistancePriority(.required, for: .vertical)

        contentContainerView.addSubview(eventListContainerView)
        eventListContainerView.autoLayout.active(with: contentContainerView) {
            $0.topAnchor.constraint(equalTo: monthContainerView.bottomAnchor)
            $0.leadingAnchor.constraint(equalTo: $1.leadingAnchor)
            $0.trailingAnchor.constraint(equalTo: $1.trailingAnchor)
            $0.bottomAnchor.constraint(equalTo: $1.bottomAnchor)
        }
    }
    
    private func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.view.backgroundColor = colorSet.dayBackground
    }
}
