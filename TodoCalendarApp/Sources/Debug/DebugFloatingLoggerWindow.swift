//
//  DebugFloatingLoggerWindow.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

#if DEBUG

import UIKit
import Extensions


private enum Constant {
    static let buttonSize: CGFloat = 44
    static let edgeInset: CGFloat = 8
    static let centerStoreKey: String = "debug.floatingLoggerButton.center"
}


// MARK: - DebugFloatingLoggerWindow

final class DebugFloatingLoggerWindow: UIWindow {

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        self.windowLevel = .alert + 1
        self.backgroundColor = .clear
        self.rootViewController = DebugFloatingLoggerViewController()
        self.isHidden = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        let isEmptyArea = hitView === self || hitView === self.rootViewController?.view
        return isEmptyArea ? nil : hitView
    }
}


// MARK: - DebugFloatingLoggerViewController

private final class DebugFloatingLoggerViewController: UIViewController {

    private let logButton = UIButton(type: .custom)
    private var didPlaceLogButton: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        self.setupLogButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let center = self.didPlaceLogButton
            ? self.logButton.center
            : self.storedCenter ?? self.defaultCenter
        self.logButton.center = self.clampedCenter(center)
        self.didPlaceLogButton = true
    }

    private func setupLogButton() {
        self.logButton.frame = .init(
            origin: .zero,
            size: .init(width: Constant.buttonSize, height: Constant.buttonSize)
        )
        self.logButton.setTitle("Log", for: .normal)
        self.logButton.setTitleColor(.red, for: .normal)
        self.logButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        self.logButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        self.logButton.layer.cornerRadius = Constant.buttonSize / 2
        self.logButton.layer.borderWidth = 1
        self.logButton.layer.borderColor = UIColor.red.withAlphaComponent(0.6).cgColor

        self.logButton.addTarget(self, action: #selector(self.showConsole), for: .touchUpInside)
        self.logButton.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(self.handleLogButtonPan(_:)))
        )
        self.view.addSubview(logButton)
    }

    @objc private func showConsole() {
        guard self.presentedViewController == nil else { return }
        let consoleViewController = LoggerConsoleBuilder().makeConsoleView()
        self.present(consoleViewController, animated: true)
    }
}


// MARK: - move log button

extension DebugFloatingLoggerViewController {

    @objc fileprivate func handleLogButtonPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        let movedCenter = CGPoint(
            x: self.logButton.center.x + translation.x,
            y: self.logButton.center.y + translation.y
        )
        self.logButton.center = self.clampedCenter(movedCenter)
        gesture.setTranslation(.zero, in: self.view)

        guard gesture.state == .ended || gesture.state == .cancelled else { return }
        self.storeCenter(self.logButton.center)
    }

    private var defaultCenter: CGPoint {
        return .init(x: self.view.bounds.maxX, y: self.view.bounds.maxY)
    }

    private var storedCenter: CGPoint? {
        return UserDefaults.standard.string(forKey: Constant.centerStoreKey)
            .map { NSCoder.cgPoint(for: $0) }
    }

    private func storeCenter(_ center: CGPoint) {
        UserDefaults.standard.set(NSCoder.string(for: center), forKey: Constant.centerStoreKey)
    }

    private func clampedCenter(_ center: CGPoint) -> CGPoint {
        let insets = self.view.safeAreaInsets
        let margin = Constant.buttonSize / 2 + Constant.edgeInset
        let minX = self.view.bounds.minX + insets.left + margin
        let maxX = self.view.bounds.maxX - insets.right - margin
        let minY = self.view.bounds.minY + insets.top + margin
        let maxY = self.view.bounds.maxY - insets.bottom - margin
        return .init(
            x: min(max(center.x, minX), maxX),
            y: min(max(center.y, minY), maxY)
        )
    }
}

#endif
