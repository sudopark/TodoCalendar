//
//  Holiday.swift
//  Domain
//
//  Created by sudo.park on 2023/06/08.
//

import Foundation
import Prelude
import Optics


// MARK: - HolidaySupportCountry

public struct HolidaySupportCountry: Sendable {
    
    // ISO 3166-2
    public let regionCode: String
    public let code: String
    public let name: String
    
    public init(regionCode: String, code: String, name: String) {
        self.regionCode = regionCode
        self.code = code
        self.name = name
    }
}

public struct Holiday: Equatable, Sendable {
    
    public let uuid: String
    public let dateString: String
    public let name: String
    
    public init(
        uuid: String,
        dateString: String,
        name: String
    ) {
        self.uuid = uuid
        self.dateString = dateString
        self.name = name
    }
    
    public func dateComponents() -> (Int, Int, Int)? {
        let components = dateString.components(separatedBy: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        return (components[0], components[1], components[2])
    }
    
    public func date(at timeZone: TimeZone) -> Date? {
        guard let components = self.dateComponents() else { return nil }
        let dateComponents = DateComponents(
            year: components.0, month: components.1, day: components.2
        )
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        return calendar.date(from: dateComponents)
    }
}
