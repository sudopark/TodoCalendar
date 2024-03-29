//
//  CalendarViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/28.
//

import UIKit
import Domain
import Scenes
import CommonPresentation

final class CalendarViewController: UIPageViewController, CalendarScene {
    
    private let viewModel: any CalendarViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any CalendarSceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any CalendarViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var monthViewControllers: [UIViewController]?
    
    override func loadView() {
        super.loadView()
        self.setupLayouts()
        self.setupStyling()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupPager()
        self.viewModel.prepare()
    }
    
    private func setupPager() {
        self.dataSource = self
        self.delegate = self
    }
    
    func addChildMonths(_ monthScenes: [any Scene]) {
        guard !monthScenes.isEmpty else { return }
        
        self.monthViewControllers = monthScenes
        let center = (monthScenes.count-1) / 2
        self.setViewControllers([monthScenes[center]], direction: .forward, animated: false)
    }
}


extension CalendarViewController: UIPageViewControllerDataSource {
    
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

extension CalendarViewController: UIPageViewControllerDelegate {
    
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


extension CalendarViewController {
    
    private func setupLayouts() {
        
    }
    
    private func setupStyling() {
        self.view.backgroundColor = self.viewAppearance.colorSet.dayBackground
    }
}
