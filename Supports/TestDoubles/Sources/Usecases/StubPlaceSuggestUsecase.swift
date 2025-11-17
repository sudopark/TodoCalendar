//
//  StubPlaceSuggestUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 11/14/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


open class StubPlaceSuggestUsecase: PlaceSuggestUsecase, @unchecked Sendable {
    
    private let allPlaces: [Place]
    private let placesSubject = CurrentValueSubject<[Place], Never>([])
    
    public init() {
        let places = (0..<30).map {
            Place("name: \($0)", .init(Double($0), Double($0)))
                |> \.addressText .~ "addr:\($0)"
        }
        self.allPlaces = places
    }
    
    public func prepare() { }
    
    public func starSuggest(_ query: String) {
        let filtered = self.allPlaces.filter { $0.placeName.contains(query) }
        self.placesSubject.send(filtered)
    }
    
    public func stopSuggest() {
        self.placesSubject.send([])
    }
    
    public var suggestPlaces: AnyPublisher<[Place], Never> {
        return self.placesSubject
            .eraseToAnyPublisher()
    }
}
