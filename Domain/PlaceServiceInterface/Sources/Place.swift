//
//  Place.swift
//  PlaceServiceInterface
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct Place: Sendable, Equatable {

    public struct Coordinate: Sendable, Equatable, Hashable {
        public let latttude: Double
        public let longitude: Double
        
        public init(_ latttude: Double, _ longitude: Double) {
            self.latttude = latttude
            self.longitude = longitude
        }
    }
    
    public let placeName: String
    public var coordinate: Coordinate?
    public var addressText: String?
    
    public init(_ placeName: String, _ coordinate: Coordinate? = nil) {
        self.placeName = placeName
        self.coordinate = coordinate
    }
}
