//
//  Time+Extension.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 10/22/23.
//

import Foundation
import Prelude
import Optics

public extension String {
    
    func date(
        form: String = "yyyy.MM.dd HH:mm:ss",
        timeZoneAbbre: String = "KST"
    ) -> Date {
        let timeZone = TimeZone(abbreviation: timeZoneAbbre) ?? TimeZone.current
        let formatter = DateFormatter()
            |> \.timeZone .~ timeZone
            |> \.dateFormat .~ "yyyy.MM.dd HH:mm:ss"
        return formatter.date(from: self)!
    }
}
