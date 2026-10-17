//
//  GradientPhotoFixture.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


struct GradientPhotoFixture {

    private enum Constant {
        static let light = UIColor(red: 0.87, green: 0.91, blue: 0.95, alpha: 1)
        static let dark = UIColor(red: 0.17, green: 0.23, blue: 0.33, alpha: 1)
    }

    private let size: CGSize

    init(_ size: CGSize) {
        self.size = size
    }

    var photo: WidgetStylePhoto {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "widget-snapshot-photos")
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let url = directory.appending(path: "\(UUID().uuidString).jpg")
        try? self.data.write(to: url, options: .atomic)
        return .init(id: nil, original: url, rendering: url)
    }

    var data: Data {
        let renderer = UIGraphicsImageRenderer(size: self.size)
        let image = renderer.image { context in
            let colors = [Constant.light.cgColor, Constant.dark.cgColor]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray, locations: [0, 1]
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: self.size.width, y: self.size.height),
                options: []
            )
        }
        return image.pngData() ?? Data()
    }
}
