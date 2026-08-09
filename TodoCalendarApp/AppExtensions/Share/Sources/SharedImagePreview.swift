//
//  SharedImagePreview.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers


/// 공유 이미지의 미리보기용 축소본.
/// 원본 Data를 화면까지 들고 가면 OCR 버퍼와 겹치는 구간에 확장 메모리 상한을 건드린다.
enum SharedImagePreview {

    private enum Constant {
        static let maxPixelSize: Int = 600
        static let jpegQuality: CGFloat = 0.8
    }

    static func make(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Constant.maxPixelSize
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }

        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, thumbnail, [
            kCGImageDestinationLossyCompressionQuality: Constant.jpegQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }
}
