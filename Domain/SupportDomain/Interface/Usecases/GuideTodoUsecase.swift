//
//  GuideTodoUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol GuideTodoUsecase: Sendable {

    func prepare()
    func completeGuideTodo()

    var isGuideTodoVisible: AnyPublisher<Bool, Never> { get }
}
