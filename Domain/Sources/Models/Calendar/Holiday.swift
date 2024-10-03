//
//  Holiday.swift
//  Domain
//
//  Created by sudo.park on 2023/06/08.
//

import Foundation


// MARK: - HolidaySupportCountry

public struct HolidaySupportCountry: Sendable {
    
    public let code: String
    public let name: String
    
    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct Holiday: Equatable, Sendable {
    
    public let dateString: String
    public let localName: String
    public let name: String
    
    public init(dateString: String, localName: String, name: String) {
        self.dateString = dateString
        self.localName = localName
        self.name = name
    }
    
    public func dateComponents() -> (Int, Int, Int)? {
        let components = dateString.components(separatedBy: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        return (components[0], components[1], components[2])
    }
}
