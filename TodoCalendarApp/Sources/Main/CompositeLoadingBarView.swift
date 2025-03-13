//
//  CompositeLoadingBarView.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 3/3/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import UIKit
import Combine
import CommonPresentation


final class CompositeLoadingBarView: UIView {
    
    private enum Constant {
        static let animationDuration: CGFloat = 2.0
        static let animationStartDebouncing: CGFloat = 1.0
        static let animtionTimeout: TimeInterval = 10.0
    }
    private let barLayer = CALayer()
    private var isLoadingCount = 0
    private var shouldShowLoading: Bool { self.isLoadingCount > 0 }
    
    private var animationStartDebouncing: AnyCancellable?
    private var animationTimeoutScheduling: AnyCancellable?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.addSublayer(self.barLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupStyling(
        _ fontSet: any FontSet, _ colorSet: any ColorSet
    ) {
        self.barLayer.backgroundColor = colorSet.accent.withAlphaComponent(0.5).cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.barLayer.position.x = -self.bounds.width
        self.barLayer.position.y = self.bounds.minY
        self.barLayer.bounds.size.width = self.bounds.width
        self.barLayer.bounds.size.height = self.bounds.height
    }
}


extension CompositeLoadingBarView {
    
    func updateIsLoading(_ isLoading: Bool) {
        let oldCount = self.isLoadingCount
        let newCount = isLoading ? oldCount + 1 : max(0, oldCount-1)
        self.isLoadingCount = newCount
        if oldCount == 0 && newCount > 0 {
            self.startAnimationAfterDebounce()
            self.scheduleClearAnimation()
        } else if oldCount > 0 && newCount == 0 {
            self.stopAnimation()
        }
    }
    
    private func startAnimationAfterDebounce() {
        
        self.animationStartDebouncing?.cancel()
        
        self.animationStartDebouncing = Timer.publish(every: Constant.animationStartDebouncing, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink(receiveValue: { [weak self] _ in
                guard self?.shouldShowLoading == true
                else {
                    self?.stopAnimation()
                    return
                }
                self?.startAnimation()
            })
    }
    
    private func scheduleClearAnimation() {
        
        self.animationTimeoutScheduling?.cancel()
        
        self.animationTimeoutScheduling = Timer.publish(every: Constant.animtionTimeout, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink(receiveValue: { [weak self] _ in
                guard self?.shouldShowLoading == true else { return }
                self?.isLoadingCount = 0
                self?.stopAnimation()
            })
    }
    
    private func startAnimation() {
        
        let width = self.bounds.width
        
        let positionAnimation = CABasicAnimation(keyPath: "position.x")
        positionAnimation.fromValue = -width/2
        positionAnimation.toValue = width * 1.5
        positionAnimation.duration = Constant.animationDuration
        positionAnimation.autoreverses = false
        positionAnimation.repeatCount = .infinity
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let widthAnimation = CABasicAnimation(keyPath: "bounds.size.width")
        widthAnimation.fromValue = width
        widthAnimation.toValue = width / 3
        widthAnimation.duration = Constant.animationDuration
        widthAnimation.autoreverses = false
        widthAnimation.repeatCount = .infinity
        widthAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        self.barLayer.add(positionAnimation, forKey: "position_animation")
        self.barLayer.add(widthAnimation, forKey: "width_animation")
    }
    
    private func stopAnimation() {
        self.animationStartDebouncing?.cancel()
        self.animationTimeoutScheduling?.cancel()
        self.barLayer.removeAllAnimations()
    }
}
