//
//  BottomSlideAnimationConstantsTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 9/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import CommonPresentation


@MainActor
struct BottomSlideAnimationConstantsTests {

    private let containerBounds = CGRect(x: 0, y: 0, width: 320, height: 500)

    @Test("높이를 안 주면 표시 프레임이 컨테이너를 가득 채운다")
    func sliderShowingFrame_whenHeightNotSpecified_fillsContainer() {
        // given
        let constant = BottomSlideAnimationConstants()

        // when
        let frame = constant.sliderShowingFrame(in: self.containerBounds)

        // then
        #expect(frame == CGRect(x: 0, y: 0, width: 320, height: 500))
    }

    @Test("숨김 프레임은 컨테이너 바로 아래에 컨테이너 폭으로 놓인다")
    func sliderHideFrame_placesSliderRightBelowContainer() {
        // given
        let constant = BottomSlideAnimationConstants(sliderShowingFrameHeight: 200)

        // when
        let frame = constant.sliderHideFrame(in: self.containerBounds)

        // then
        #expect(frame == CGRect(x: 0, y: 500, width: 320, height: 200))
    }

    @Test("높이를 주면 표시 프레임이 컨테이너 바닥에 붙는다")
    func sliderShowingFrame_whenHeightSpecified_alignsToContainerBottom() {
        // given
        let constant = BottomSlideAnimationConstants(sliderShowingFrameHeight: 200)

        // when
        let frame = constant.sliderShowingFrame(in: self.containerBounds)

        // then
        #expect(frame == CGRect(x: 0, y: 300, width: 320, height: 200))
    }
    @Test("높이를 주면 창 크기가 바뀌어도 높이는 두고 바닥을 따라가고, 안 주면 컨테이너를 따라 늘어난다")
    func sliderAutoresizingMask_followsContainerByHeightOption() {
        // given
        let fixedHeight = BottomSlideAnimationConstants(sliderShowingFrameHeight: 200)
        let fullHeight = BottomSlideAnimationConstants()

        // when
        let fixedHeightMask = fixedHeight.sliderAutoresizingMask
        let fullHeightMask = fullHeight.sliderAutoresizingMask

        // then
        #expect(fixedHeightMask == [.flexibleWidth, .flexibleTopMargin])
        #expect(fullHeightMask == [.flexibleWidth, .flexibleHeight])
    }
}
