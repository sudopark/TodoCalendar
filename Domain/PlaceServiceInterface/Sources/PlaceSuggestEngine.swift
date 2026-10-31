//
//  PlaceSuggestEngine.swift
//  PlaceServiceInterface
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - PlaceSuggestEngine

public protocol PlaceSuggestEngine: AnyObject {

    func prepare()
    func suggest(query: String) -> AnyPublisher<[Place], any Error>
}
