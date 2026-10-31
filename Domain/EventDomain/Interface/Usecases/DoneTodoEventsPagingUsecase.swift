//
//  DoneTodoEventsPagingUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 5/9/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - DoneTodoEventsPagingUsecase

public protocol DoneTodoEventsPagingUsecase: Sendable {
    
    func reload()
    func loadMore()
    
    var events: AnyPublisher<[DoneTodoEvent]?, Never> { get }
    var loadFailed: AnyPublisher<any Error, Never> { get }
}
