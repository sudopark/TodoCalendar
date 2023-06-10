//
//  Holiday.swift
//  Domain
//
//  Created by sudo.park on 2023/06/08.
//

import Foundation


// MARK: - HolidaySupportCountry

public struct HolidaySupportCountry {
    
    public let code: String
    public let name: String
    
    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct Holiday {
    
    public let dateString: String
    public let localName: String
    public let name: String
    
    public init(dateString: String, localName: String, name: String) {
        self.dateString = dateString
        self.localName = localName
        self.name = name
    }
}
