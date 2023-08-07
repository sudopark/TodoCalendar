//
//  FontSet.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import UIKit


// MARK: - FontSet

public protocol FontSet: Sendable {
    
    // calendar component
    var weekday: UIFont { get }
    var day: UIFont { get }
    var eventOnDay: UIFont { get }
}


// MARK: - default font set

public struct SystemDefaultFontSet: FontSet {

    // calendar component
    public let weekday: UIFont = UIFont.systemFont(ofSize: 12)
    public let day: UIFont = UIFont.systemFont(ofSize: 14)
    public let eventOnDay: UIFont = UIFont.systemFont(ofSize: 10)
}
