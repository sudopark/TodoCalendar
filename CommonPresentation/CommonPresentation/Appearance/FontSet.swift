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
    var eventMore: UIFont { get }
    
    var bigMonth: UIFont { get }
    var normal: UIFont { get }
    var subNormal: UIFont { get}
    var subNormalWithBold: UIFont { get }
    
    func size(_ size: CGFloat, weight: UIFont.Weight) -> UIFont
}

extension FontSet {
    
    public func size(_ size: CGFloat) -> UIFont {
        return self.size(size, weight: .regular)
    }
}


// MARK: - default font set

public struct SystemDefaultFontSet: FontSet {

    // calendar component
    public let weekday: UIFont = UIFont.systemFont(ofSize: 12)
    public let day: UIFont = UIFont.systemFont(ofSize: 14)
    public let eventOnDay: UIFont = UIFont.systemFont(ofSize: 10)
    public let eventMore: UIFont = UIFont.systemFont(ofSize: 9)
    
    public let bigMonth: UIFont = UIFont.systemFont(ofSize: 32, weight: .semibold)
    public let normal: UIFont = UIFont.systemFont(ofSize: 16)
    public let subNormal: UIFont = UIFont.systemFont(ofSize: 12)
    public let subNormalWithBold: UIFont = UIFont.systemFont(ofSize: 12, weight: .bold)
    
    public func size(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}
