//
//  CalendarMonthPagerViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Extensions
import Scenes


final class CalendarMonthPagerViewController: UIPageViewController {

    private let viewModel: any CalendarViewModel

    init(viewModel: any CalendarViewModel) {
        self.viewModel = viewModel
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var monthViewControllers: [UIViewController]?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.dataSource = self
        self.delegate = self
    }

    func addChildMonths(_ monthScenes: [any Scene]) {
        guard !monthScenes.isEmpty else { return }

        self.monthViewControllers = monthScenes
        let center = (monthScenes.count-1) / 2
        self.setViewControllers([monthScenes[center]], direction: .forward, animated: false)
    }

    func changeFocus(at index: Int) {
        guard let center = self.monthViewControllers?[safe: index] else { return }
        self.setViewControllers([center], direction: .forward, animated: false)
    }

    // 애니메이션 중 setViewControllers를 재호출하면 이후 스와이프가 엉뚱한 페이지를 보여준다
    private var isSlidingFocus: Bool = false

    func slideFocus(to index: Int, isNext: Bool, completed: @escaping @Sendable () -> Void) {
        guard !self.isSlidingFocus,
              let target = self.monthViewControllers?[safe: index]
        else { return }

        self.isSlidingFocus = true
        self.setViewControllers(
            [target],
            direction: isNext ? .forward : .reverse,
            animated: true
        ) { [weak self] finished in
            self?.isSlidingFocus = false
            guard finished else { return }
            completed()
        }
    }
}


extension CalendarMonthPagerViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let viewControllers = self.monthViewControllers,
              var index = viewControllers.firstIndex(of: viewController)
        else { return nil }

        if index == 0 {
            index = viewControllers.count
        }
        index -= 1

        return viewControllers[index]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let viewControllers = self.monthViewControllers,
              var index = viewControllers.firstIndex(of: viewController)
        else { return nil }

        index += 1
        if index == viewControllers.count {
            index = 0
        }
        return viewControllers[index]
    }
}

extension CalendarMonthPagerViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let totalViewControllers = self.monthViewControllers,
              !totalViewControllers.isEmpty,
              let previousFirstViewController = previousViewControllers.first,
              let currentViewController = pageViewController.viewControllers?.first,
              let previousIndex = totalViewControllers.firstIndex(of: previousFirstViewController),
              let currentIndex = totalViewControllers.firstIndex(of: currentViewController)
        else { return }

        self.viewModel.focusChanged(from: previousIndex, to: currentIndex)
    }
}
