//
//  UIColor+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import UIKit
import Prelude
import Domain


extension UIColor {
   public convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   public convenience init(rgb: Int) {
       self.init(
           red: (rgb >> 16) & 0xFF,
           green: (rgb >> 8) & 0xFF,
           blue: rgb & 0xFF
       )
   }
    
    public static func from(hex: String) -> UIColor? {
        let r, g, b, a: CGFloat

        guard hex.hasPrefix("#") else { return nil }
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }
        
        switch hexColor.count {
        case 8:
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
            return UIColor(red: r, green: g, blue: b, alpha: a)
            
        case 6:
            r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000ff) / 255
            a = CGFloat(1.0)
            return UIColor(red: r, green: g, blue: b, alpha: a)
         
        default: break
        }
        
        return nil
    }
    
    public var isLight: Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // 표준 휘도 계산 공식 (Rec. 709)
        // 인간의 눈은 초록색에 가장 민감하고 파란색에 가장 둔감합니다.
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        
        // 휘도가 0.5보다 크면 밝은 색으로 판단
        return luminance > 0.5
    }
}


import SwiftUI

extension UIColor {
    
    public var asColor: Color {
        return Color(self)
    }
}

extension Color {
    
    public static func from(_ hex: String) -> Color? {
        return UIColor.from(hex: hex).map { Color($0) }
    }
    
    public func hex(_ env: EnvironmentValues) -> String? {
        // TODO: resolve 는 나중에(p3 color일때 rgb 다르게 나옴 vs description은 제대로 나옴)
        let rgba: (r: Float, g: Float, b: Float, a: Float)
        let resolve = self.resolve(in: env)
        rgba = (
            resolve.red, resolve.green, resolve.blue, resolve.opacity
        )
        
        return String(
            format: "#%02lX%02lX%02lX%02lX",
            (rgba.r * 255) |> lroundf,
            (rgba.g * 255) |> lroundf,
            (rgba.b * 255) |> lroundf,
            (rgba.a * 255) |> lroundf
        )
    }
}
