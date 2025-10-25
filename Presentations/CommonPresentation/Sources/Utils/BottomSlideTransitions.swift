//
//  BottomSlideTransitions.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import UIKit

// MARK: - BottomSlide show/hide animation

@MainActor
public struct BottomSlideAnimationConstants {
    
    let animationDuration: TimeInterval
    let sliderShowingFrameHeight: CGFloat
    
    private static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    public init(animationDuration: TimeInterval = 0.25,
                sliderShowingFrameHeight: CGFloat? = nil) {
        self.animationDuration = animationDuration
        
        let defaultHeight: () -> CGFloat = {
            return Self.screenSize.height
        }
        self.sliderShowingFrameHeight = sliderShowingFrameHeight ?? defaultHeight()
    }
    
    private var sliderSize: CGSize {
        return .init(width: Self.screenSize.width, height: self.sliderShowingFrameHeight)
    }
    
    var sliderHideFrame: CGRect {
        let origin = CGPoint(x: 0, y: Self.screenSize.height)
        return .init(origin: origin, size: self.sliderSize)
    }
    
    var sliderShowingFrame: CGRect {
        let origin = CGPoint(x: 0, y: Self.screenSize.height - self.sliderShowingFrameHeight)
        return .init(origin: origin, size: self.sliderSize)
    }
}

@MainActor
public final class BottomSlidShowing: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let constant: BottomSlideAnimationConstants
    public init(constant: BottomSlideAnimationConstants) {
        self.constant = constant
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.constant.animationDuration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        guard let showingController = transitionContext.viewController(forKey: .to),
              let showingView = showingController.view else {
            return
        }
        let constant = self.constant
        
        let shadowView = ShadowView(frame: UIScreen.main.bounds)
        shadowView.updateDimpercent(0.1)
        transitionContext.containerView.addSubview(shadowView)
        
        transitionContext.containerView.addSubview(showingView)
        
        showingView.frame = constant.sliderHideFrame
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, animations: {
            showingView.frame = constant.sliderShowingFrame
            
            shadowView.updateDimpercent(1.0)
        }, completion: { success in
            shadowView.updateDimpercent(1.0)
            transitionContext.completeTransition(success)
        })
    }
}


@MainActor
public final class BottomSlideHiding: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let constant: BottomSlideAnimationConstants
    public init(constant: BottomSlideAnimationConstants) {
        self.constant = constant
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.constant.animationDuration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        guard let slideViewController = transitionContext.viewController(forKey: .from),
              let slideView = slideViewController.view else {
            return
        }
        
        let constant = self.constant
        
        let shadowView = transitionContext.containerView.subviews.first(where: { $0 is ShadowView }) as? ShadowView
        shadowView?.updateDimpercent(1.0)
        
        slideView.frame = constant.sliderShowingFrame
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, animations: {
            slideView.frame = constant.sliderHideFrame
            shadowView?.updateDimpercent(0.1)
        }, completion: { _ in
            if transitionContext.transitionWasCancelled {
                transitionContext.completeTransition(false)
            } else {
                shadowView?.removeFromSuperview()
                transitionContext.completeTransition(true)
            }
        })
    }
}

final class ShadowView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .black.withAlphaComponent(0.3)
        self.alpha = 0.0
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateDimpercent(_ percent: CGFloat) {
        self.alpha = percent
        let shouldHide = percent == 0
        self.isHidden = shouldHide
    }
}


// MARK: - BottomPullPangestureDimissalInteractor

@MainActor
public final class BottomPullPangestureDimissalInteractor: UIPercentDrivenInteractiveTransition {
    
    var hasStart = false
    private var shouldFinish = false
    private var dismissController: (() -> Void)?
    
    public override init() { }
    
    public func addDismissPangesture(
        _ targetView: UIView,
        _ dismissController: @escaping () -> Void
    ) {
        
        self.dismissController = dismissController
        
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePangesture(_:)))
        gestureRecognizer.delegate = self
        gestureRecognizer.maximumNumberOfTouches = 1
        targetView.addGestureRecognizer(gestureRecognizer)
    }
}

extension BottomPullPangestureDimissalInteractor: UIGestureRecognizerDelegate {
    
    @objc private func handlePangesture(_ gesture: UIPanGestureRecognizer) {
        
        let transition = gesture.translation(in: gesture.view)
        
        let safeAreaBottomPadding = gesture.view?.window?.safeAreaInsets.bottom ?? 0
        let totalLength = (gesture.view?.frame.height ?? UIScreen.main.bounds.height) - safeAreaBottomPadding
        var percent = transition.y / totalLength
        
        percent = min(1, percent); percent = max(0, percent)
        
        switch gesture.state {
        case .began:
            self.hasStart = true
            self.dismissController?()
            
        case .changed:
            self.shouldFinish = percent > 0.3
            self.update(percent)
            
        case .cancelled:
            self.hasStart = false
            self.cancel()
            
        case .ended:
            self.hasStart = false
            self.shouldFinish ? self.finish() : self.cancel()
            
        default: break
        }
    }
    
    // 스크롤뷰가 처리할 수 있는 상황에서는 dismiss 제스처 시작을 막음
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let hostView = gestureRecognizer.view
        else { return true }
        
        let velocity = pan.velocity(in: hostView)
        // 수평 성분이 더 크면 시작하지 않음
        if abs(velocity.x) > abs(velocity.y) {
            return false
        }
        
        // 손가락 위치 기준으로 하위에서 UIScrollView 탐색
        let location = pan.location(in: hostView)
        if let hitView = hostView.hitTest(location, with: nil),
           let scrollView = hitView.findSuperview(of: UIScrollView.self) {
            
            // 스크롤뷰 최상단 기준 오프셋(topLimit = -adjustedContentInset.top)
            let topLimit = -scrollView.adjustedContentInset.top
            let isAtTopOrBeyond = scrollView.contentOffset.y <= topLimit
            
            // 위로 드래그면 스크롤뷰가 우선
            if velocity.y < 0 {
                return false
            }
            // 아직 위로 더 스크롤할 수 있으면(= 최상단 아님) 스크롤뷰가 우선
            if !isAtTopOrBeyond {
                return false
            }
            // 최상단이고 아래로 드래그 → dismiss 시작 허용
            return true
        }
        
        // 스크롤뷰가 없으면 dismiss 제스처 허용
        return true
    }
    
    // 동시 인식을 막아 충돌 방지 (필요 시 특정 제스처와만 동시 허용으로 세분화 가능)
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// 상위뷰 탐색 유틸
fileprivate extension UIView {
    func findSuperview<T: UIView>(of type: T.Type) -> T? {
        var v: UIView? = self
        while let current = v {
            if let matched = current as? T { return matched }
            v = current.superview
        }
        return nil
    }
}


// MARK: - animation manager

public final class BottomSlideTransitionAnimationManager: NSObject, UIViewControllerTransitioningDelegate {
    
    public var constant: BottomSlideAnimationConstants!
    
    public let interactor = BottomPullPangestureDimissalInteractor()
    
    public override init() {
        super.init()
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return BottomSlideHiding(constant: self.constant ?? .init())
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return BottomSlidShowing(constant: self.constant ?? .init())
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        
        return self.interactor.hasStart ? self.interactor : nil
    }
}


extension UIViewController {
    
    public func attachBottomSlideDismiss(interactor: BottomPullPangestureDimissalInteractor) {
        
        let dimissAction: () -> Void = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        
        interactor.addDismissPangesture(self.view, dimissAction)
    }
}
