//
//  SharedImagePreviewTests.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import TodoCalendarAppShare


struct SharedImagePreviewTests {

    private func makeSourceImageData(size: CGSize) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }
}

extension SharedImagePreviewTests {

    @Test func preview_downsamplesBigImage() throws {
        // given
        let source = self.makeSourceImageData(size: .init(width: 3000, height: 3000))

        // when
        let preview = SharedImagePreview.make(from: source)

        // then
        let unwrapped = try #require(preview)
        let image = try #require(UIImage(data: unwrapped))
        #expect(max(image.size.width, image.size.height) <= 600)
    }

    @Test func preview_whenNotAnImage_returnsNil() {
        // given
        let broken = Data("not an image".utf8)

        // when
        let preview = SharedImagePreview.make(from: broken)

        // then
        #expect(preview == nil)
    }
}
