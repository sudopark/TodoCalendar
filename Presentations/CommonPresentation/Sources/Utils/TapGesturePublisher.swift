//
//  TapGesturePublisher.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/27.
//

import UIKit
import Combine


struct TapGesturePublisher: Publisher {
    
    public typealias Output = Void
    public typealias Failure = Never
    
    private let view: UIView
    
    init(_ view: UIView) {
        self.view = view
    }
    
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Void == S.Input {
        let subscription = TapGestureSubscription(subscriber, view)
        subscriber.receive(subscription: subscription)
    }
}

final class TapGestureSubscription<S: Subscriber>: Subscription, @unchecked Sendable where S.Input == Void, S.Failure == Never {
    
    private var subscriber: S?
    private let view: UIView
    
    init(_ subscriber: S, _ view: UIView) {
        self.subscriber = subscriber
        self.view = view
        Task { @MainActor [weak self] in
            self?.addGestureRecognizer()
        }
    }
    
    @MainActor
    private func addGestureRecognizer() {
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(self.handler))
        view.addGestureRecognizer(gesture)
    }
    
    func request(_ demand: Subscribers.Demand) { }
    
    func cancel() {
        self.subscriber = nil
    }
    
    @objc
    private func handler() {
        _ = self.subscriber?.receive(())
    }
}
