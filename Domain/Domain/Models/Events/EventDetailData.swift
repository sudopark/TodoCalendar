//
//  EventDetailData.swift
//  Domain
//
//  Created by sudo.park on 10/28/23.
//

import Foundation


// MARK: - EventDetail

public struct Place: Sendable, Equatable {

    public struct Coordinate: Sendable, Equatable {
        public let latttude: Double
        public let longitude: Double
        
        public init(_ latttude: Double, _ longitude: Double) {
            self.latttude = latttude
            self.longitude = longitude
        }
    }
    
    public let placeName: String
    public let coordinate: Coordinate
    public var addressText: String?
    
    public init(_ placeName: String, _ coordinate: Coordinate) {
        self.placeName = placeName
        self.coordinate = coordinate
    }
}

public struct EventDetailData: Sendable, Equatable {
    
    public let eventId: String
    public var place: Place?
    public var url: String?
    public var memo: String?
    
    public init(_ eventId: String) {
        self.eventId = eventId
    }
}
