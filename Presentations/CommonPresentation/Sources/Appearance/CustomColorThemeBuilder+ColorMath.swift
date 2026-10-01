//
//  CustomColorThemeBuilder+ColorMath.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit


// MARK: - ColorMath

extension CustomColorThemeBuilder {

    struct ColorMath: Sendable {

        func relativeLuminance(of color: UIColor) -> CGFloat {
            let rgb = color.rgbComponents
            return 0.2126 * rgb.red.linearizedSRGBChannel
                + 0.7152 * rgb.green.linearizedSRGBChannel
                + 0.0722 * rgb.blue.linearizedSRGBChannel
        }

        func contrastRatio(_ color: UIColor, _ other: UIColor) -> CGFloat {
            let luminances = [self.relativeLuminance(of: color), self.relativeLuminance(of: other)]
            let lighter = luminances.max() ?? 0
            let darker = luminances.min() ?? 0
            return (lighter + 0.05) / (darker + 0.05)
        }

        func mixed(_ color: UIColor, with other: UIColor, ratio: CGFloat) -> UIColor {
            let from = color.rgbComponents
            let to = other.rgbComponents
            return UIColor(
                red: from.red * (1 - ratio) + to.red * ratio,
                green: from.green * (1 - ratio) + to.green * ratio,
                blue: from.blue * (1 - ratio) + to.blue * ratio,
                alpha: 1
            )
        }

        func eightBit(_ color: UIColor) -> UIColor {
            let rgb = color.rgbComponents
            let bytes: [Int] = [rgb.red, rgb.green, rgb.blue].map { Int((max(0, min(1, $0)) * 255).rounded()) }
            return UIColor(rgb: bytes[0] << 16 | bytes[1] << 8 | bytes[2])
        }
    }
}


// MARK: - OKLCH

extension CustomColorThemeBuilder {

    struct OKLCH: Equatable, Sendable {

        var lightness: CGFloat
        var chroma: CGFloat
        var hue: CGFloat

        init(lightness: CGFloat, chroma: CGFloat, hue: CGFloat) {
            self.lightness = lightness
            self.chroma = chroma
            self.hue = hue
        }

        init(_ color: UIColor) {
            let rgb = color.rgbComponents
            let r = rgb.red.linearizedSRGBChannel
            let g = rgb.green.linearizedSRGBChannel
            let b = rgb.blue.linearizedSRGBChannel
            let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
            let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
            let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
            let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
            let bAxis = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
            let chroma = hypot(a, bAxis)
            let degrees = atan2(bAxis, a) * 180 / .pi
            self.init(
                lightness: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                chroma: chroma,
                hue: chroma < 1e-4 ? 0 : (degrees < 0 ? degrees + 360 : degrees)
            )
        }

        func with(lightness: CGFloat) -> OKLCH {
            return OKLCH(lightness: lightness, chroma: chroma, hue: hue)
        }

        func rotated(by degrees: CGFloat) -> OKLCH {
            let rotated = (hue + degrees).truncatingRemainder(dividingBy: 360)
            return OKLCH(
                lightness: lightness,
                chroma: chroma,
                hue: rotated < 0 ? rotated + 360 : rotated
            )
        }

        var uiColor: UIColor {
            let linear = self.linearRGB
            return linear.isOutOfGamut ? self.reducingChroma().uiColor : linear.uiColor
        }
    }
}


// MARK: - gamut

extension CustomColorThemeBuilder.OKLCH {

    fileprivate func reducingChroma() -> CustomColorThemeBuilder.OKLCH {
        return .init(
            lightness: lightness,
            chroma: chroma * Constant.chromaReduction,
            hue: hue
        )
    }

    fileprivate var linearRGB: LinearRGB {
        let radians = hue * .pi / 180
        let a = chroma * cos(radians)
        let b = chroma * sin(radians)
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        return LinearRGB(
            red: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            green: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            blue: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
            chroma: chroma
        )
    }
}

private struct LinearRGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let chroma: CGFloat

    var isOutOfGamut: Bool {
        let channels = [red, green, blue]
        let tolerance = Constant.gamutTolerance
        let outside = (channels.min() ?? 0) < -tolerance || (channels.max() ?? 0) > 1 + tolerance
        return outside && chroma > Constant.chromaFloor
    }

    var uiColor: UIColor {
        return UIColor(
            red: encoded(red), green: encoded(green), blue: encoded(blue), alpha: 1
        )
    }

    private func encoded(_ linear: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, linear))
        return clamped <= 0.0031308
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}


// MARK: - sRGB

private extension UIColor {

    var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue)
    }
}

private extension CGFloat {

    var linearizedSRGBChannel: CGFloat {
        return self <= 0.04045 ? self / 12.92 : pow((self + 0.055) / 1.055, 2.4)
    }
}


private enum Constant {
    static let chromaFloor: CGFloat = 0.01
    static let chromaReduction: CGFloat = 0.95
    static let gamutTolerance: CGFloat = 1e-4
}
