//
//  PlaceSuggestUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 11/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import CombineSchedulers
import Extensions
import PlaceServiceInterface


// MARK: - PlaceSuggestUsecase

public protocol PlaceSuggestUsecase: AnyObject, Sendable {
    
    func prepare()
    func starSuggest(_ query: String)
    func stopSuggest()
    
    var suggestPlaces: AnyPublisher<[Place], Never> { get }
}
