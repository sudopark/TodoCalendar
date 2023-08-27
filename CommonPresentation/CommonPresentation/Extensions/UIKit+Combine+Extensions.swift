//
//  UIKit+Combine+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/27.
//

import UIKit
import Combine


extension UIView {
    
    public func addTapGestureRecognizerPublisher(
        _ count: Int = 1,
        _ throttleMilliseconds: Int = 200,
        with impactStyle: UIImpactFeedbackGenerator.FeedbackStyle? = nil
    ) -> AnyPublisher<Void, Never> {
        
        self.isUserInteractionEnabled = true
        let existingTapGestures = self.gestureRecognizers?.filter {
            $0 is UITapGestureRecognizer
        }
        existingTapGestures?.forEach {
            self.removeGestureRecognizer($0)
        }
        
        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = count
        self.addGestureRecognizer(gesture)
        
        let runFeedbackIfNeed: () -> Void = {
            guard let impactStyle else { return }
            let generator = UIImpactFeedbackGenerator(style: impactStyle)
            generator.prepare()
            generator.impactOccurred()
        }
        
        return TapGesturePublisher(self)
            .handleEvents(receiveOutput: runFeedbackIfNeed)
            .throttle(for: .milliseconds(throttleMilliseconds), scheduler: RunLoop.main, latest: true)
            .eraseToAnyPublisher()
    }
}
