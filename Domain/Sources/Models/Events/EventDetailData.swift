//
//  EventDetailData.swift
//  Domain
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
import Prelude
import Optics


// MARK: - EventDetail

public struct EventDetailData: Sendable, Equatable {
    
    public let eventId: String
    public var place: Place?
    public var url: String?
    public var memo: String?
    
    public init(_ eventId: String) {
        self.eventId = eventId
    }
    
    public func copy(_ newEventId: String) -> EventDetailData {
        return .init(newEventId)
            |> \.place .~ place
            |> \.url .~ url
            |> \.memo .~ memo
    }
}
