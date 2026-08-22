//
//  GatedAdBannerUIViewTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UIKit

@testable import TodoCalendarApp


@MainActor
final class GatedAdBannerUIViewTests {

    private func makeSUT(
        canShowAd: CurrentValueSubject<Bool, Never>,
        makeBanner: @escaping @MainActor () -> UIView = { UIView() }
    ) -> GatedAdBannerUIView {
        return GatedAdBannerUIView(
            canShowAd: canShowAd.eraseToAnyPublisher(),
            makeBanner: makeBanner
        )
    }
}


// MARK: - 허용 전 fail-closed

extension GatedAdBannerUIViewTests {

    @Test func gatedBanner_whenNotAllowed_hasNoBannerSubview() async throws {
        // given
        let gate = CurrentValueSubject<Bool, Never>(false)
        let sut = self.makeSUT(canShowAd: gate)

        // when
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sut.subviews.isEmpty)
    }

    @Test func gatedBanner_whenNotAllowed_intrinsicContentSizeIsZero() async throws {
        // given
        let gate = CurrentValueSubject<Bool, Never>(false)
        let sut = self.makeSUT(canShowAd: gate)

        // when
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sut.intrinsicContentSize == .zero)
    }
}


// MARK: - 허용 시 배너 추가

extension GatedAdBannerUIViewTests {

    @Test func gatedBanner_whenAllowed_addBannerSubview() async throws {
        // given
        let gate = CurrentValueSubject<Bool, Never>(false)
        let sut = self.makeSUT(canShowAd: gate)

        // when
        gate.send(true)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sut.subviews.count == 1)
        #expect(sut.intrinsicContentSize == CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric))
    }
}


// MARK: - 재진입

extension GatedAdBannerUIViewTests {

    @Test func gatedBanner_whenDisallowedAfterAllowed_removeBannerSubview() async throws {
        // given
        let gate = CurrentValueSubject<Bool, Never>(false)
        let sut = self.makeSUT(canShowAd: gate)
        gate.send(true)
        try await Task.sleep(for: .milliseconds(50))

        // when
        gate.send(false)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sut.subviews.isEmpty)
        #expect(sut.intrinsicContentSize == .zero)
    }

    @Test func gatedBanner_whenToggledMultipleTimes_createsNewBannerEachTimeAllowed() async throws {
        // given
        let gate = CurrentValueSubject<Bool, Never>(false)
        let sut = self.makeSUT(canShowAd: gate)
        gate.send(true)
        try await Task.sleep(for: .milliseconds(50))
        let firstBanner = sut.subviews.first

        // when
        gate.send(false)
        try await Task.sleep(for: .milliseconds(50))
        gate.send(true)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sut.subviews.count == 1)
        #expect(sut.subviews.first !== firstBanner)
    }
}
