//
//  WidgetGalleryPreviewTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing

@testable import WidgetScenes


struct WidgetGalleryPreviewTests {

    @Test
    func canvas_onPad_systemFamiliesUsePadSize() {
        // given
        let idiom: UIUserInterfaceIdiom = .pad

        // when
        let small = WidgetPreviewCanvas.systemSmall.size(for: idiom)
        let medium = WidgetPreviewCanvas.systemMedium.size(for: idiom)
        let large = WidgetPreviewCanvas.systemLarge.size(for: idiom)

        // then
        #expect(small == CGSize(width: 160, height: 160))
        #expect(medium == CGSize(width: 356, height: 160))
        #expect(large == CGSize(width: 356, height: 356))
    }

    @Test(arguments: [UIUserInterfaceIdiom.phone, .unspecified])
    func canvas_onPhone_systemFamiliesKeepPhoneSize(_ idiom: UIUserInterfaceIdiom) {
        // given
        // when
        let small = WidgetPreviewCanvas.systemSmall.size(for: idiom)
        let medium = WidgetPreviewCanvas.systemMedium.size(for: idiom)
        let large = WidgetPreviewCanvas.systemLarge.size(for: idiom)

        // then
        #expect(small == CGSize(width: 170, height: 170))
        #expect(medium == CGSize(width: 364, height: 170))
        #expect(large == CGSize(width: 364, height: 382))
    }

    @Test(arguments: [WidgetPreviewCanvas.accessoryInline, .accessoryRectangular, .accessoryCircular])
    func canvas_lockScreenFamiliesKeepSameSizeOnPhoneAndPad(_ canvas: WidgetPreviewCanvas) {
        // given
        let expectedSizes: [WidgetPreviewCanvas: CGSize] = [
            .accessoryInline: .init(width: 240, height: 26),
            .accessoryRectangular: .init(width: 160, height: 72),
            .accessoryCircular: .init(width: 72, height: 72)
        ]

        // when
        let onPhone = canvas.size(for: .phone)
        let onPad = canvas.size(for: .pad)

        // then
        #expect(onPhone == expectedSizes[canvas])
        #expect(onPad == expectedSizes[canvas])
    }

    @Test
    func canvas_onPad_largeIsSquare() {
        // given
        let canvas = WidgetPreviewCanvas.systemLarge

        // when
        let aspectOnPad = canvas.previewAspect(for: .pad)
        let aspectOnPhone = canvas.previewAspect(for: .phone)

        // then
        #expect(aspectOnPad == 1)
        #expect(abs(aspectOnPhone - 364.0 / 382.0) < 0.0001)
    }

    @Test
    func canvas_onPad_previewScaleFitsPadSize() {
        // given
        let canvas = WidgetPreviewCanvas.systemMedium
        let box = CGSize(width: 178, height: 1000)

        // when
        let scaleOnPad = canvas.previewScale(fitting: box, idiom: .pad)
        let scaleOnPhone = canvas.previewScale(fitting: box, idiom: .phone)

        // then
        #expect(scaleOnPad == 0.5)
        #expect(abs(scaleOnPhone - 178.0 / 364.0) < 0.0001)
    }
}
