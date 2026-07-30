//
//  DDayTargetSelectIntentTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import TodoCalendarAppWidget


// MARK: - entity id 왕복

struct DDayTargetEntityIdTests {

    @Test("반복 일정 id는 반복 조각을 포함한다")
    func entityId_whenRepeating_containsRepeatingFragment() {
        // given
        let target = DDayTargetEventId(kind: .schedule, rawId: "s1")

        // when
        let entityId = target.entityId(isRepeating: true)

        // then
        #expect(entityId.contains(DDayTargetEventId.repeatingIdFragment) == true)
    }

    @Test("비반복 일정 id는 반복 조각을 포함하지 않는다")
    func entityId_whenNotRepeating_hasNoRepeatingFragment() {
        // given
        let target = DDayTargetEventId(kind: .schedule, rawId: "s1")

        // when
        let entityId = target.entityId(isRepeating: false)

        // then
        #expect(entityId.contains(DDayTargetEventId.repeatingIdFragment) == false)
    }

    @Test("회차 지정 id를 왕복해도 회차 키가 보존된다")
    func entityId_withTurnKey_roundTrips() throws {
        // given
        let target = DDayTargetEventId(kind: .schedule, rawId: "s1", turnKey: "1200..<1300")

        // when
        let restored = DDayTargetEventId(entityId: target.entityId(isRepeating: true))

        // then
        let restored2 = try #require(restored)
        #expect(restored2.kind == .schedule)
        #expect(restored2.rawId == "s1")
        #expect(restored2.turnKey == "1200..<1300")
    }

    @Test("`::`를 쓰는 공휴일 id를 왕복해도 이름이 보존된다")
    func entityId_whenHoliday_roundTrips() throws {
        // given
        let key = HolidayTargetKey(
            countryCode: "KR", dateString: "2027-03-01", name: "삼일절"
        )
        let target = DDayTargetEventId(kind: .holiday, rawId: key.rawId)

        // when
        let restored = DDayTargetEventId(entityId: target.entityId(isRepeating: false))

        // then
        let restored2 = try #require(restored)
        #expect(restored2.kind == .holiday)
        #expect(restored2.rawId == key.rawId)
        #expect(restored2.turnKey == nil)
    }

    /// `DDayWidgetConfigurationIntent.parameterSummary`는 이 값을 상수로 참조할 수 없다
    /// (메타데이터 추출기가 소스 텍스트를 그대로 담는다) — 리터럴로 중복돼 있으니 함께 지킨다.
    @Test("반복 조각은 parameterSummary 조건 리터럴과 같은 값이다")
    func repeatingIdFragment_matchesParameterSummaryLiteral() {
        #expect(DDayTargetEventId.repeatingIdFragment == "|repeating|")
    }

    @Test("반복 마커가 없는 id는 해석하지 않는다")
    func initEntityId_whenMarkIsMissing_returnsNil() {
        // given + when
        let restored = DDayTargetEventId(entityId: "schedule|s1")

        // then
        #expect(restored == nil)
    }
}


// MARK: - 후보 정렬

struct DDayTargetCandidateSortTests {

    private func makeCandidate(
        _ name: String, at time: TimeInterval, isRepeating: Bool = false
    ) -> DDayTargetCandidate {
        return DDayTargetCandidate(
            targetId: .init(kind: .schedule, rawId: name),
            name: name,
            time: .at(time),
            isRepeating: isRepeating
        )
    }

    /// 시간 오름차순으로 미리 정렬된 입력 — 실제 호출부(asSuggestions)와 같은 상태.
    private var candidates: [DDayTargetCandidate] {
        return [
            self.makeCandidate("past-far", at: 100),
            self.makeCandidate("repeat-old", at: 500, isRepeating: true),
            self.makeCandidate("past-near", at: 900),
            self.makeCandidate("today", at: 1000),
            self.makeCandidate("upcoming-near", at: 1500),
            self.makeCandidate("upcoming-far", at: 2000),
            self.makeCandidate("repeat-new", at: 5000, isRepeating: true)
        ]
    }

    @Test("반복 → 다가오는 순 → 지난 순으로 배열된다")
    func sortedForSuggestion_ordersByTier() {
        // when
        let sorted = self.candidates.sortedForSuggestion(
            since: 1000, upcomingLimit: 40, pastLimit: 10
        )

        // then
        #expect(
            sorted.map { $0.name } == [
                "repeat-old", "repeat-new",
                "today", "upcoming-near", "upcoming-far",
                "past-near", "past-far"
            ]
        )
    }

    @Test("다가오는 이벤트와 지난 이벤트의 상한은 따로 적용된다")
    func sortedForSuggestion_appliesLimitsPerTier() {
        // when
        let sorted = self.candidates.sortedForSuggestion(
            since: 1000, upcomingLimit: 2, pastLimit: 1
        )

        // then
        #expect(
            sorted.map { $0.name } == [
                "repeat-old", "repeat-new", "today", "upcoming-near", "past-near"
            ]
        )
    }

    @Test("반복 일정은 상한과 무관하게 모두 남는다")
    func sortedForSuggestion_keepsAllRepeatings() {
        // when
        let sorted = self.candidates.sortedForSuggestion(
            since: 1000, upcomingLimit: 0, pastLimit: 0
        )

        // then
        #expect(sorted.map { $0.name } == ["repeat-old", "repeat-new"])
    }
}
