//
//  DDayText.swift
//  Extensions
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct DDayText {

    public let text: String

    public init(_ interval: Int) {
        switch interval {
        case ..<0:
            self.text = "D+\(abs(interval))"
        case 0:
            self.text = "D-Day"
        default:
            self.text = "D-\(interval)"
        }
    }
}
