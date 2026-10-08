//
//  CalendarTwoColumnsViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Extensions
import Scenes
import CommonPresentation


private enum Constant {
    static let listWidthRatio: CGFloat = 0.4
    static let maxListWidth: CGFloat = 420
    static let dividerWidth: CGFloat = 0.5
    // 호스팅 뷰의 압축 저항(750)보다 높아야 intrinsic 폭에 밀리지 않고, 상한(required)보다는 낮아야 넓은 창에서 420pt 로 멈춘다
    static let proportionalWidthPriority = UILayoutPriority(999)
}


final class CalendarTwoColumnsViewController: UIViewController, CalendarTwoColumnsScene {

    private let viewModel: any CalendarTwoColumnsViewModel
    private let monthsViewController: UIViewController
    private let listViewController: UIHostingController<AnyView>
    let viewAppearance: ViewAppearance

    private let divider = UIView()
    private let cancellables = CancelBag()

    @MainActor
    var interactor: (any CalendarTwoColumnsSceneInteractor)? { self.viewModel }

    init(
        viewModel: any CalendarTwoColumnsViewModel,
        monthsViewController: UIViewController,
        listView: CalendarTwoColumnsListContainerView,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.monthsViewController = monthsViewController
        self.listViewController = UIHostingController(
            rootView: AnyView(listView.eventHandler(\.stateBinding, { $0.bind(viewModel) }))
        )
        self.viewAppearance = viewAppearance
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupLayout()
        self.bind()
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


// MARK: - layout

extension CalendarTwoColumnsViewController {

    private func setupLayout() {
        [self.monthsViewController, self.listViewController].forEach { child in
            self.addChild(child)
            self.view.addSubview(child.view)
            child.didMove(toParent: self)
            child.view.translatesAutoresizingMaskIntoConstraints = false
        }
        self.view.addSubview(self.divider)
        self.divider.translatesAutoresizingMaskIntoConstraints = false

        let months = self.monthsViewController.view!
        let list = self.listViewController.view!
        let proportionalListWidth = list.widthAnchor.constraint(
            equalTo: self.view.widthAnchor, multiplier: Constant.listWidthRatio
        )
        proportionalListWidth.priority = Constant.proportionalWidthPriority
        NSLayoutConstraint.activate([
            months.topAnchor.constraint(equalTo: self.view.topAnchor),
            months.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            months.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            months.trailingAnchor.constraint(equalTo: self.divider.leadingAnchor),

            self.divider.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.divider.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.divider.widthAnchor.constraint(equalToConstant: Constant.dividerWidth),
            self.divider.trailingAnchor.constraint(equalTo: list.leadingAnchor),

            list.topAnchor.constraint(equalTo: self.view.topAnchor),
            list.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            list.widthAnchor.constraint(lessThanOrEqualToConstant: Constant.maxListWidth),
            proportionalListWidth
        ])
    }

    private func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.view.backgroundColor = colorSet.bg0
        self.divider.backgroundColor = colorSet.line
    }
}
