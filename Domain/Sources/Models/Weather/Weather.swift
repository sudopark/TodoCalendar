//
//  Weather.swift
//  Domain
//
//  Created by sudo.park on 1/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation



// MARK: - Location

public protocol UserLocation: Sendable {
    
    var latitude: Double { get }
    var longitude: Double { get }
}


// MARK: - Weather

public enum Weather: Sendable {
    
    public enum Condition: Sendable {
        case blowingDust
        case clear
        case cloudy
        case foggy
        case haze
        case mostlyClear
        case mostlyCloudy
        case partlyCloudy
        case smoky
        case breezy
        case windy
        case drizzle
        case heavyRain
        case isolatedThunderStorms
        case rain
        case sunShowers
        case scatteredThunderstorms
        case strongStorms
        case thunderstorms
        case frigid
        case hail
        case hot
        case flurries
        case sleet
        case snow
        case sunFlurries
        case wintryMix
        case blizzard
        case blowingSnow
        case freezingDizzle
        case freezingRain
        case heavySnow
        case hurricane
        case tropicalStorm
    }
    
    public struct Current: Sendable {
        
        public let temperature: Measurement<UnitTemperature>
        public let condition: Condition
        public var conditionDescription: String?
        
        public init(temperature: Measurement<UnitTemperature>, condition: Condition) {
            self.temperature = temperature
            self.condition = condition
        }
    }
    
    public struct DailyTemperatureForecast: Sendable {
        public let high: Measurement<UnitTemperature>
        public let low: Measurement<UnitTemperature>
        
        public init(high: Measurement<UnitTemperature>, low: Measurement<UnitTemperature>) {
            self.high = high
            self.low = low
        }
    }
}

public struct WeatherSummary: Sendable {
    
    public let current: Weather.Current
    public let todayTemperatureForecast: Weather.DailyTemperatureForecast
    
    public init(current: Weather.Current, todayTemperatureForecast: Weather.DailyTemperatureForecast) {
        self.current = current
        self.todayTemperatureForecast = todayTemperatureForecast
    }
}
