//
//  WeatherFetchUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WeatherKit
import Extensions

public protocol WeatherFetchUsecase: Sendable {
    
    func currentWeatherSummary() async throws -> WeatherSummary
}

public protocol UserLocationFetchService {
    
    func currentLocation() async throws -> UserLocation
}



// MARK: - WeatherKitBaseFetchUsecase

public final class WeatherKitBaseFetchUsecaseImple: WeatherFetchUsecase {
    
    
}

extension WeatherKitBaseFetchUsecaseImple {
    
    public func currentWeatherSummary() async throws -> WeatherSummary {
        
        throw RuntimeError("failed")
    }
}
