//
//  ContinuousMonthsViewControllerTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Combine
import Domain
import CommonPresentation
import UnitTestHelpKit

@testable import CalendarScenes
import CalendarPresentation


@MainActor
final class ContinuousMonthsViewControllerTests {

    private let center = CalendarMonth(year: 2023, month: 9)
    private var window: UIWindow?

    private func makeViewController() async throws -> (ContinuousMonthsViewController, SpyContinuousMonthsViewModel, UICollectionView) {
        let viewModel = SpyContinuousMonthsViewModel(center: self.center)
        let viewController = ContinuousMonthsViewController(viewModel: viewModel, viewAppearance: self.makeAppearance())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 456, height: 560))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
        let collectionView = try #require(viewController.view.subviews.compactMap { $0 as? UICollectionView }.first)
        try await self.waitOnMain("첫 섹션 배치") {
            collectionView.numberOfSections == 5 && collectionView.contentOffset.y > 0
        }
        return (viewController, viewModel, collectionView)
    }

    // AsyncEffectWaitable.waitEffect 는 조건을 메인 밖에서 읽어 UIKit 레이아웃 단언이 깨진다
    private func waitOnMain(_ description: String, until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        guard condition() else {
            throw MainWaitTimeout(description: "3000ms 안에 조건이 참이 되지 않았다 — \(description)")
        }
    }

    // VC 는 섹션을 DispatchQueue.main 으로 받아서, 그 뒤에 넣은 작업이 돌면 앞선 전달은 끝나 있다
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func makeAppearance() -> ViewAppearance {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        return ViewAppearance(setting: setting, isSystemDarkTheme: false)
    }

    private func anchor(_ collectionView: UICollectionView, _ section: Int) -> CGFloat {
        return collectionView.layoutAttributesForItem(at: IndexPath(item: 0, section: section))?.frame.minY ?? -1
    }

    private func weekCounts(_ collectionView: UICollectionView) -> [Int] {
        return (0..<collectionView.numberOfSections).map { collectionView.numberOfItems(inSection: $0) }
    }

    private func expectedWeekCounts(center: CalendarMonth) -> [Int] {
        return center.fixtureBufferMonths().map { $0.fixtureWeekCount }
    }

    private func month(after count: Int) -> CalendarMonth {
        return (0..<count).reduce(self.center) { acc, _ in acc.nextMonth() }
    }

    private func releaseDrag(
        _ viewController: ContinuousMonthsViewController,
        _ collectionView: UICollectionView,
        momentum: CGFloat
    ) -> CGFloat {
        var target = CGPoint(x: 0, y: collectionView.contentOffset.y + momentum)
        viewController.scrollViewWillEndDragging(
            collectionView, withVelocity: .zero, targetContentOffset: &target
        )
        return target.y
    }
}


// MARK: - 초기 배치·스냅 목표

extension ContinuousMonthsViewControllerTests {

    @Test func viewController_initialLayout_focusedSectionAtTop() async throws {
        // given
        let (_, _, collectionView) = try await self.makeViewController()

        // when
        let offset = collectionView.contentOffset.y

        // then
        #expect(self.weekCounts(collectionView) == self.expectedWeekCounts(center: self.center))
        #expect(offset == self.anchor(collectionView, 2))
    }

    @Test func viewController_whenFlickPastHalfOfMonth_targetNextSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let next = self.anchor(collectionView, 3)

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: (next - current) * 0.6)

        // then
        #expect(target == next)
    }

    @Test func viewController_whenFlickBackPastHalfOfPreviousMonth_targetPreviousSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let previous = self.anchor(collectionView, 1)

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: (previous - current) * 0.6)

        // then
        #expect(target == previous)
    }

    @Test func viewController_whenDragAndMomentumStayUnderHalf_targetCurrentSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let height = self.anchor(collectionView, 3) - current
        collectionView.contentOffset.y = current + height * 0.2

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: height * 0.2)

        // then
        #expect(target == current)
    }

    @Test func viewController_whenDragAndMomentumTogetherPassHalf_targetNextSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let next = self.anchor(collectionView, 3)
        collectionView.contentOffset.y = current + (next - current) * 0.2

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: (next - current) * 0.35)

        // then
        #expect(target == next)
    }

    @Test func viewController_whenDragBackAndMomentumTogetherPassHalf_targetPreviousSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let previous = self.anchor(collectionView, 1)
        collectionView.contentOffset.y = current + (previous - current) * 0.2

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: (previous - current) * 0.35)

        // then
        #expect(target == previous)
    }

    @Test func viewController_whenReleaseSlowlyNearCurrent_targetCurrentSectionTop() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let current = self.anchor(collectionView, 2)
        let next = self.anchor(collectionView, 3)
        collectionView.contentOffset.y = current + (next - current) * 0.4

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: 0)

        // then
        #expect(target == current)
    }

    @Test func viewController_whenFlingFast_moveOnlyOneMonth() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.anchor(collectionView, 4)

        // when
        let target = self.releaseDrag(viewController, collectionView, momentum: 1000)

        // then
        #expect(target == self.anchor(collectionView, 3))
    }
}


// MARK: - 레이아웃 전 도착

extension ContinuousMonthsViewControllerTests {

    @Test func viewController_whenSectionsArriveBeforeLayout_alignFocusedSectionAfterLayout() async throws {
        // given
        let viewModel = SpyContinuousMonthsViewModel(center: self.center)
        let viewController = ContinuousMonthsViewController(viewModel: viewModel, viewAppearance: self.makeAppearance())
        viewController.loadViewIfNeeded()
        let collectionView = try #require(viewController.view.subviews.compactMap { $0 as? UICollectionView }.first)
        try await self.waitOnMain("레이아웃 전 섹션 도착") { collectionView.numberOfSections == 5 }

        // when
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 456, height: 560))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
        viewController.view.layoutIfNeeded()

        // then
        #expect(self.anchor(collectionView, 2) > 0)
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
    }
}


// MARK: - 멈춘 동안 앵커 유지

extension ContinuousMonthsViewControllerTests {

    @Test func viewController_whenOffsetDriftsWhileIdle_restoreFocusedSectionTopOnLayout() async throws {
        // given
        let (_, _, collectionView) = try await self.makeViewController()
        let top = self.anchor(collectionView, 2)

        // when
        collectionView.contentOffset.y = top + 36
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()

        // then
        #expect(collectionView.contentOffset.y == top)
    }

    @Test func viewController_whenLayoutWhileDragging_keepUserOffset() async throws {
        // given
        let (viewController, _, collectionView) = try await self.makeViewController()
        let top = self.anchor(collectionView, 2)
        viewController.scrollViewWillBeginDragging(collectionView)

        // when
        collectionView.contentOffset.y = top + 36
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()

        // then
        #expect(collectionView.contentOffset.y == top + 36)
    }
}


// MARK: - 사용자 스냅 정착

extension ContinuousMonthsViewControllerTests {

    @Test func viewController_whenSettledOnOtherSection_callScrolledToThatMonth() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        let target = self.releaseDrag(viewController, collectionView, momentum: 1000)
        collectionView.contentOffset.y = target

        // when
        viewController.scrollViewDidEndDecelerating(collectionView)

        // then
        #expect(viewModel.didScrolledTo == self.month(after: 1))
    }

    @Test func viewController_whenSectionsShifted_keepFocusedSectionAtTop() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 1000)
        viewController.scrollViewDidEndDecelerating(collectionView)

        // when
        viewModel.sendSections(center: self.month(after: 1))
        let expectedCounts = self.expectedWeekCounts(center: self.month(after: 1))
        try await self.waitOnMain("옮긴 버퍼 적용") { self.weekCounts(collectionView) == expectedCounts }

        // then
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
    }

    @Test func viewController_whenSectionsShifted_keepCellsOfOverlappingWeeks() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 1000)
        viewController.scrollViewDidEndDecelerating(collectionView)
        collectionView.layoutIfNeeded()
        let cellBeforeShift = try #require(collectionView.cellForItem(at: IndexPath(item: 0, section: 3)))

        // when
        viewModel.sendSections(center: self.month(after: 1))
        let expectedCounts = self.expectedWeekCounts(center: self.month(after: 1))
        try await self.waitOnMain("옮긴 버퍼 적용") { self.weekCounts(collectionView) == expectedCounts }

        // then
        #expect(collectionView.cellForItem(at: IndexPath(item: 0, section: 2)) === cellBeforeShift)
    }

    @Test func viewController_whenSectionsArriveWhileDragging_applyAfterSettle() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        let originCounts = self.weekCounts(collectionView)
        viewController.scrollViewWillBeginDragging(collectionView)

        // when
        viewModel.sendSections(center: self.month(after: 4))
        await self.drainMainQueue()
        let countsWhileDragging = self.weekCounts(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 0)
        viewController.scrollViewDidEndDragging(collectionView, willDecelerate: false)

        // then
        #expect(countsWhileDragging == originCounts)
        #expect(self.weekCounts(collectionView) == self.expectedWeekCounts(center: self.month(after: 4)))
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
        #expect(viewModel.didScrolledTo == nil)
    }

    @Test func viewController_whenUserSnapsWhileSectionsPending_dropPendingAndCallScrolledTo() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        let originCounts = self.weekCounts(collectionView)
        viewController.scrollViewWillBeginDragging(collectionView)
        viewModel.sendSections(center: self.month(after: 5))
        await self.drainMainQueue()

        // when
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 1000)
        viewController.scrollViewDidEndDecelerating(collectionView)
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: -1000)
        viewController.scrollViewDidEndDecelerating(collectionView)

        // then
        #expect(viewModel.didScrolledTo == self.month(after: 1))
        #expect(self.weekCounts(collectionView) == originCounts)
    }

    @Test func viewController_whenUserSnapsToPendingFocusedMonth_applyPendingSections() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        viewController.scrollViewWillBeginDragging(collectionView)
        viewModel.sendSections(center: self.month(after: 1))
        await self.drainMainQueue()

        // when
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 1000)
        viewController.scrollViewDidEndDecelerating(collectionView)

        // then
        #expect(self.weekCounts(collectionView) == self.expectedWeekCounts(center: self.month(after: 1)))
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
        #expect(viewModel.didScrolledTo == self.month(after: 1))
    }

    @Test func viewController_whenSectionsArriveWhileDecelerating_applyAfterDecelerationEnds() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        let originCounts = self.weekCounts(collectionView)
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 0)
        viewController.scrollViewDidEndDragging(collectionView, willDecelerate: true)

        // when
        viewModel.sendSections(center: self.month(after: 4))
        await self.drainMainQueue()
        let countsWhileDecelerating = self.weekCounts(collectionView)
        viewController.scrollViewDidEndDecelerating(collectionView)

        // then
        #expect(countsWhileDecelerating == originCounts)
        #expect(self.weekCounts(collectionView) == self.expectedWeekCounts(center: self.month(after: 4)))
    }
}


// MARK: - 외부 포커스 이동

extension ContinuousMonthsViewControllerTests {

    @Test func viewController_whenExternalFocusInBuffer_animateThenApplySections() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        let originCounts = self.weekCounts(collectionView)

        // when
        viewModel.sendSections(center: self.month(after: 1))
        await self.drainMainQueue()
        let countsWhileAnimating = self.weekCounts(collectionView)
        viewController.scrollViewDidEndScrollingAnimation(collectionView)

        // then
        #expect(countsWhileAnimating == originCounts)
        #expect(self.weekCounts(collectionView) == self.expectedWeekCounts(center: self.month(after: 1)))
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
        #expect(viewModel.didScrolledTo == nil)
    }

    @Test func viewController_whenUserDragsDuringExternalAnimation_treatAsUserScroll() async throws {
        // given
        let (viewController, viewModel, collectionView) = try await self.makeViewController()
        viewModel.sendSections(center: self.month(after: 1))
        await self.drainMainQueue()

        // when
        viewController.scrollViewWillBeginDragging(collectionView)
        collectionView.contentOffset.y = self.releaseDrag(viewController, collectionView, momentum: 1000)
        viewController.scrollViewDidEndDecelerating(collectionView)

        // then
        #expect(viewModel.didScrolledTo == self.month(after: 2))
    }

    @Test func viewController_whenExternalFocusOutOfBuffer_applySectionsImmediately() async throws {
        // given
        let (_, viewModel, collectionView) = try await self.makeViewController()

        // when
        viewModel.sendSections(center: self.month(after: 4))
        let expectedCounts = self.expectedWeekCounts(center: self.month(after: 4))
        try await self.waitOnMain("버퍼 밖 달 즉시 적용") { self.weekCounts(collectionView) == expectedCounts }

        // then
        #expect(collectionView.contentOffset.y == self.anchor(collectionView, 2))
        #expect(viewModel.didScrolledTo == nil)
    }
}



// MARK: - 셀 이벤트 배선

extension ContinuousMonthsViewControllerTests {

    @Test func eventHandler_whenBound_forwardDaySelectionAndShareToViewModel() {
        // given
        let viewModel = SpyContinuousMonthsViewModel(center: self.center)
        let eventHandler = ContinuousMonthsViewEventHandler()
        let selectedDay = DayCellViewModel(year: 2023, month: 9, day: 13, isNotCurrentMonth: false, accentDay: nil)
        let sharedDay = DayCellViewModel(year: 2023, month: 8, day: 31, isNotCurrentMonth: true, accentDay: nil)

        // when
        eventHandler.bind(viewModel)
        eventHandler.daySelected(selectedDay)
        eventHandler.shareEvents(.week, sharedDay)

        // then
        #expect(viewModel.didSelectDay == selectedDay)
        #expect(viewModel.didShareKind == .week)
        #expect(viewModel.didShareDay == sharedDay)
    }
}

private struct MainWaitTimeout: Error {
    let description: String
}
