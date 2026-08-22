//
//  StubGuideTodoUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


public final class StubGuideTodoUsecase: GuideTodoUsecase, @unchecked Sendable {

    private let isVisibleSubject: CurrentValueSubject<Bool, Never>

    public init(isVisible: Bool = true) {
        self.isVisibleSubject = .init(isVisible)
    }

    public var didPrepare: Bool?

    public func prepare() {
        self.didPrepare = true
    }

    public var didCompleteGuideTodo: Bool?

    public func completeGuideTodo() {
        self.didCompleteGuideTodo = true
        self.isVisibleSubject.send(false)
    }

    public var isGuideTodoVisible: AnyPublisher<Bool, Never> {
        return self.isVisibleSubject.eraseToAnyPublisher()
    }
}
