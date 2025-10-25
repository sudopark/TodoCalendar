//
//  KeyboardHeightObserver.swift
//  CommonPresentation
//
//  Created by sudo.park on 5/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine


public struct KeyboardFrameChanges: Equatable {
    
    public enum EventType:Equatable {
        case show
//        case change
        case hide
    }
    
    public let type: EventType
    public let from: CGRect
    public let to: CGRect
    public let duration: TimeInterval
}


extension Notification {
    
    @MainActor
    func keyboardChanges(_ type: KeyboardFrameChanges.EventType) -> KeyboardFrameChanges? {
        
        guard let from = self.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
              let to = self.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = self.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return nil
        }
        return .init(type: type, from: from, to: to, duration: duration)
    }
}


@MainActor
@Observable public final class KeyboardHeightObserver {
    
    public var showingKeyboardHeight: CGFloat = 0
    public var isVisible: Bool {
        return self.showingKeyboardHeight > 0
    }
    
    @ObservationIgnored
    private var observing: Cancellable?
    
    public init() {
        self.observeHeight()
    }
    
    private func observeHeight() {
     
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.keyboardChanges(.show) }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { $0.keyboardChanges(.hide) }
        let willChangeAsShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { $0.keyboardChanges(.show) }
        
        let changes = Publishers.Merge(
            Publishers.Merge(willShow, willChangeAsShow).removeDuplicates(),
            willHide
        )
        
        self.observing = changes
            .sink(receiveValue: { [weak self] change in
                let showingHeight = change.type == .show ? change.to.height : 0
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showingKeyboardHeight = showingHeight
                }
            })
    }
}

