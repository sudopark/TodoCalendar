//
//  WidgetGalleryItemTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Extensions

@testable import WidgetScenes


struct WidgetGalleryItemTests {

    /// 확장 타겟을 볼 수 없어 `Widget` 선언의 kind 목록을 여기 사본으로 둔다.
    /// 배치 가능한 것만이다 — `EventCountdownLiveActivity` 와 `AICommandControlWidget` 은 뺀다.
    private let placeableWidgetKinds: Set<String> = [
        "TodayAndNextWidget", "MonthWidget", "EventList", "TodaySummary",
        "ForemostEventWidget", "NextEventWidget", "NextRemainEventWidget",
        "AICommandShortcutWidget", "DDayWidget",
        "DoubleMonthWidget", "EventAndMonthWidget", "EventAndForemostWidget", "TodayAndMonthWidget",
        "OneWeekEventsWidget", "TwoWeekEventsWidget", "ThreeWeekEventsWidget", "FourWeekEventsWidget",
        "CurrentMonthEventsWidget", "LastMonthEventsWidget", "NextMonthEventsWidget"
    ]

    @Test
    func item_variantKindsCoverAllPlaceableWidgetDeclarations() {
        // given
        let items = WidgetGalleryItem.allCases

        // when
        let kinds = Set(items.flatMap { $0.variants }.map { $0.kind })

        // then
        #expect(kinds == placeableWidgetKinds)
    }

    @Test
    func item_variantsCoverEveryDeclaredVariant() {
        // given
        let items = WidgetGalleryItem.allCases

        // when
        let listed = Set(items.flatMap { $0.variants })

        // then
        #expect(listed == Set(WidgetGalleryVariant.allCases))
    }

    @Test
    func item_variantIdsAreUnique() {
        // given
        let variants = WidgetGalleryItem.allCases.flatMap { $0.variants }

        // when
        let ids = variants.map { $0.id }

        // then
        #expect(Set(ids).count == ids.count)
    }

    @Test(
        "잠금화면 변형의 라벨은 사이즈와 함께 잠금화면임을 알린다",
        arguments: WidgetGalleryVariant.allCases
    )
    func variant_labelTellsLockScreen(_ variant: WidgetGalleryVariant) {
        // given
        let lockScreenLabel = "widget.gallery::lockScreen::label"
            .localized(with: variant.label)

        // when
        let detailLabel = variant.detailLabel

        // then
        if variant.canvas.isLockScreen {
            #expect(detailLabel == lockScreenLabel)
        } else {
            #expect(detailLabel == variant.label)
        }
    }
}
