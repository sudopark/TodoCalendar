//
//  CalendarViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/28.
//

import UIKit
import Domain
import Scenes


final class CalendarViewController: UIPageViewController, CalendarScene {
    
    private let viewModel: CalendarViewModel
    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
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
    
    func addChildMonths(_ singleMonthScenes: [any SingleMonthScene]) {
        guard !singleMonthScenes.isEmpty else { return }
        
        self.monthViewControllers = singleMonthScenes
        let center = (singleMonthScenes.count-1) / 2
        self.setViewControllers([singleMonthScenes[center]], direction: .forward, animated: false)
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
              let previousFirstViewController = previousViewControllers.first,
              let currentLastViewController = pageViewController.viewControllers?.last
        else { return }

        let isMoveToRight = previousFirstViewController == currentLastViewController
        if isMoveToRight {
            // TODO: update is move to right
            print("is move to right")
            self.viewModel.focusMoveToNextMonth()
        } else {
            // TODO: update is move to left
            print("is move to left")
            self.viewModel.focusMoveToPreviousMonth()
        }
    }
}


extension CalendarViewController {
    
    private func setupLayouts() {
        
    }
    
    private func setupStyling() {
        
    }
}
//
//private class DummyViewController: UIViewController {
//
//    private let label = UILabel()
//    private var int: Int?
//    func setInt(_ int: Int) {
//        self.int = int
//        self.label.text = "\(int)"
//    }
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//            self.view.addSubview(label)
//            label.translatesAutoresizingMaskIntoConstraints = false
//            NSLayoutConstraint.activate([
//                label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
//                label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
//            ])
//            label.textAlignment = .center
//
//    }
//}
//
//
//import SwiftUI
//
//private struct CalendarPagerControllerView: UIViewControllerRepresentable {
//
//    func makeUIViewController(context: Context) -> some UIViewController {
//        let viewController = CalendarViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
//        return viewController
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
//}
//
//struct PagerPreview: PreviewProvider {
//
//    static var previews: some View {
//        return CalendarPagerControllerView()
//    }
//}
