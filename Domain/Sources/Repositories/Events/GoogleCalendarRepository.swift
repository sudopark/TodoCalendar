//
//  GoogleCalendarRepository.swift
//  Domain
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol GoogleCalendarRepository: Sendable {
    
    func loadColors() -> AnyPublisher<GoogleCalendarColors, any Error>
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendarEventTag], any Error>
}
