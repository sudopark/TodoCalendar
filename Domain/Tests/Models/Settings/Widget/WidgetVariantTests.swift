//
//  WidgetVariantTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


private struct OtherStyleSetting: WidgetStyleSetting {

    var isOn: Bool

    static let initial = OtherStyleSetting(isOn: true)
}


/// 필드가 없으면 Equatable 합성이 늘 true 라, 타입 캐스트가 유일한 구분자다.
private struct OtherEmptyStyleSetting: WidgetStyleSetting {

    static let initial = OtherEmptyStyleSetting()
}


struct WidgetVariantTests {

    @Test("꾸미기 대상이 아닌 변형은 payload 타입을 갖지 않는다")
    func settingType_onlyCustomizableVariantHasOne() {
        // given
        let variants = WidgetVariant.allCases

        // when
        let variantsHavingType = variants.filter { $0.settingType != nil }

        // then
        #expect(variantsHavingType == [
            .todayAndNextMedium,
            .eventListSmall, .eventListMedium, .eventListLarge,
            .monthSmall, .todaySummarySmall,
            .foremostSmall, .foremostMedium,
            .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
            .currentMonthEvents, .lastMonthEvents, .nextMonthEvents,
            .aiCommandSmall
        ])
    }

    @Test("Month 와 WeekEvents 는 각자의 payload 타입을 갖는다")
    func settingType_monthAndWeekEventsHaveOwnPayload() {
        // given
        let weekEvents = WidgetVariant.allCases.filter { $0.styleVariant == .oneWeekEvents }

        // when + then
        #expect(WidgetVariant.monthSmall.settingType == MonthStyleSetting.self)
        #expect(weekEvents.allSatisfy { $0.settingType == WeekEventsStyleSetting.self })
        #expect(weekEvents.count == 7)
    }

    @Test("WeekEvents 7변형은 스타일 좌표 하나를 공유한다")
    func styleVariant_weekEventsShareOneCoordinate() {
        // given
        let weekEvents: [WidgetVariant] = [
            .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
            .currentMonthEvents, .lastMonthEvents, .nextMonthEvents
        ]

        // when
        let styleVariants = weekEvents.map { $0.styleVariant }

        // then
        #expect(styleVariants == Array(repeating: .oneWeekEvents, count: 7))
    }

    @Test("공유 변형군은 어느 변형에서 물어도 같은 목록을 낸다")
    func styleSharingVariants_fromAnyMember_listsWholeGroup() {
        // given
        let weekEvents: [WidgetVariant] = [
            .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
            .currentMonthEvents, .lastMonthEvents, .nextMonthEvents
        ]

        // when
        let groups = weekEvents.map { $0.styleSharingVariants }

        // then
        #expect(groups.allSatisfy { $0 == weekEvents })
        #expect(WidgetVariant.monthSmall.styleSharingVariants == [.monthSmall])
    }

    @Test("스타일을 공유하지 않는 변형은 자기 자신을 좌표로 쓴다")
    func styleVariant_nonSharingVariantPointsItself() {
        // given
        let sharing = Set<WidgetVariant>([
            .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
            .currentMonthEvents, .lastMonthEvents, .nextMonthEvents,
            .eventListMedium, .eventListLarge, .foremostMedium
        ])
        let others = WidgetVariant.allCases.filter { sharing.contains($0) == false }

        // when + then
        #expect(others.allSatisfy { $0.styleVariant == $0 })
        #expect(WidgetVariant.monthSmall.styleVariant == .monthSmall)
    }

    @Test("EventList 3변형과 Foremost 홈 2변형은 각각 대표 좌표로 접힌다")
    func styleVariant_sharingVariantsFoldIntoRepresentative() {
        // given
        let eventList: [WidgetVariant] = [.eventListSmall, .eventListMedium, .eventListLarge]
        let foremostHome: [WidgetVariant] = [.foremostSmall, .foremostMedium]

        // when + then
        #expect(eventList.map { $0.styleVariant } == Array(repeating: .eventListSmall, count: 3))
        #expect(foremostHome.map { $0.styleVariant } == Array(repeating: .foremostSmall, count: 2))
        #expect(WidgetVariant.eventListLarge.styleSharingVariants == eventList)
        #expect(WidgetVariant.foremostMedium.styleSharingVariants == foremostHome)
    }

    @Test("Foremost 잠금화면 변형은 홈 변형에 접히지 않는다")
    func styleVariant_lockScreenVariantsDoNotFold() {
        // given
        let inline = WidgetVariant.foremostInline

        // when + then
        #expect(inline.styleVariant == .foremostInline)
        #expect(inline.styleSharingVariants == [.foremostInline])
        #expect(inline.isCustomizable == false)
        #expect(WidgetVariant.aiCommandCircular.styleVariant == .aiCommandCircular)
        #expect(WidgetVariant.aiCommandCircular.isCustomizable == false)
    }

    @Test("항목이 없는 payload 끼리도 타입으로 갈린다")
    func isOwnSetting_distinguishesEmptyPayloadTypes() {
        // given
        let eventList = WidgetVariant.eventListSmall

        // when + then
        #expect(eventList.isOwnSetting(EventListStyleSetting.initial) == true)
        #expect(eventList.isOwnSetting(OtherEmptyStyleSetting.initial) == false)
        #expect(
            WidgetVariant.todayAndNextMedium.isOwnSetting(EventListStyleSetting.initial) == false
        )
    }

    @Test("변형이 내는 초기 설정은 그 payload 타입의 초기값이다")
    func initialSetting_isPayloadTypeInitial() {
        // given
        let today = WidgetVariant.todaySummarySmall

        // when + then
        #expect(today.initialSetting as? TodayStyleSetting == TodayStyleSetting.initial)
        #expect(
            WidgetVariant.monthSmall.initialSetting as? MonthStyleSetting
                == MonthStyleSetting.initial
        )
        #expect(WidgetVariant.doubleMonthMedium.initialSetting == nil)
    }

    @Test("변형은 자기 payload 타입만 자기 설정으로 본다")
    func isOwnSetting_onlyForItsPayloadType() {
        // given
        let today = WidgetVariant.todaySummarySmall

        // when + then
        #expect(today.isOwnSetting(TodayStyleSetting.initial) == true)
        #expect(today.isOwnSetting(OtherStyleSetting.initial) == false)
        #expect(WidgetVariant.monthSmall.isOwnSetting(TodayStyleSetting.initial) == false)
        #expect(WidgetVariant.monthSmall.isOwnSetting(MonthStyleSetting.initial) == true)
        #expect(
            WidgetVariant.threeWeekEvents.isOwnSetting(WeekEventsStyleSetting.initial) == true
        )
    }

    @Test("payload 타입이 다르면 같은 설정으로 보지 않는다")
    func isSameSetting_whenPayloadTypeDiffers_returnsFalse() {
        // given
        let setting = TodayStyleSetting.initial
        let changed = TodayStyleSetting(
            showHolidayName: false, showTimeZone: true, showMonthYear: true,
            showTotalCount: true, showTodoCount: true, showScheduleCount: true
        )

        // when + then
        #expect(setting.isSame(setting) == true)
        #expect(setting.isSame(changed) == false)
        #expect(setting.isSame(OtherStyleSetting.initial) == false)
    }
}
