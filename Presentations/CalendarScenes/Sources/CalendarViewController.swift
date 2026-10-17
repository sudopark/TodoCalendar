//
//  CalendarViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/28.
//

import UIKit
import Combine
import Domain
import Extensions
import Scenes
import CommonPresentation

final class CalendarViewController: UIViewController, CalendarScene {
    
    private let viewModel: any CalendarViewModel
    private let pagerViewController: CalendarMonthPagerViewController
    private var twoColumnsViewController: UIViewController?
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any CalendarSceneInteractor)? { self.viewModel }
    
    private let cancellables = CancelBag()
    
    init(
        viewModel: any CalendarViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        self.pagerViewController = CalendarMonthPagerViewController(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupLayouts()
        self.viewModel.prepare()
        self.bind()
        self.bindColumnLayout()
    }
    
    func addChildMonths(_ monthScenes: [any Scene]) {
        self.pagerViewController.addChildMonths(monthScenes)
    }
    
    func changeFocus(at index: Int) {
        self.pagerViewController.changeFocus(at: index)
    }

    func slideFocus(to index: Int, isNext: Bool, completed: @escaping @Sendable () -> Void) {
        self.pagerViewController.slideFocus(to: index, isNext: isNext, completed: completed)
    }

    func attachTwoColumns(_ twoColumns: any CalendarTwoColumnsScene) {
        self.twoColumnsViewController = twoColumns
        self.embed(twoColumns)
        twoColumns.view.isHidden = true
    }

    func showColumnLayout(_ layout: CalendarColumnLayout) {
        let isTwoColumns = layout == .twoColumns
        self.pagerViewController.view.isHidden = isTwoColumns
        self.twoColumnsViewController?.view.isHidden = !isTwoColumns
    }

    private func bindColumnLayout() {
        self.notifyColumnLayout()
        self.registerForTraitChanges(
            [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
        ) { (self: Self, _: UITraitCollection) in
            self.notifyColumnLayout()
        }
    }

    private func notifyColumnLayout() {
        let layout = CalendarColumnLayout(
            horizontal: self.traitCollection.horizontalSizeClass,
            vertical: self.traitCollection.verticalSizeClass
        )
        self.viewModel.columnLayoutChanged(layout)
    }

    private func bind() {
     
        self.viewAppearance.didUpdated
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tuple in
                self?.setupStyling(tuple.1, tuple.2)
            })
            .store(in: self.cancellables)
    }
}


extension CalendarViewController {
    
    private func setupLayouts() {
        self.embed(self.pagerViewController)
    }

    private func embed(_ child: UIViewController) {
        self.addChild(child)
        self.view.addSubview(child.view)
        child.didMove(toParent: self)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    private func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.view.backgroundColor = colorSet.bg0
    }
}


// MARK: - CalendarColumnLayout + size class

extension CalendarColumnLayout {

    init(horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass) {
        let isBothRegular = horizontal == .regular && vertical == .regular
        self = isBothRegular ? .twoColumns : .singleColumn
    }
}
