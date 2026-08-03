//
//  DDayTargetSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import AppIntents
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - DDayTargetEventId + entity id

extension DDayTargetEventId {

    private enum Constant {
        /// 공휴일 rawId가 `::`를 쓰므로 겹치지 않는 구분자를 쓴다.
        static let separator: String = "|"
        static let repeatingMark: String = "repeating"
        static let singleMark: String = "single"
    }

    /// 반복 일정 entity id에 항상 들어가는 조각.
    ///
    /// `parameterSummary`의 조건(`When`)은 entity의 id 문자열만 비교할 수 있어서
    /// "이 대상이 반복 일정인가"를 id에 실어야 회차 파라미터 노출을 가를 수 있다.
    static var repeatingIdFragment: String {
        return "\(Constant.separator)\(Constant.repeatingMark)\(Constant.separator)"
    }

    /// `schedule|repeating|<uuid>[|<customKey>]` / `holiday|single|<code>::<date>::<name>`
    func entityId(isRepeating: Bool) -> String {
        let mark = isRepeating ? Constant.repeatingMark : Constant.singleMark
        let segments = [self.kind.rawValue, mark, self.rawId] + (self.turnKey.map { [$0] } ?? [])
        return segments.joined(separator: Constant.separator)
    }

    init?(entityId: String) {
        let segments = entityId.components(separatedBy: Constant.separator)
        guard segments.count >= 3,
              let kind = DDayTargetKind(rawValue: segments[0])
        else { return nil }
        self.init(
            kind: kind,
            rawId: segments[2],
            turnKey: segments.count >= 4 ? segments[3] : nil
        )
    }
}


// MARK: - DDayTargetDateFormatter

enum DDayTargetDateFormatter {

    /// "2027년 3월 15일 (월)" 계열 — 로케일 템플릿.
    static func dateText(of time: EventTime, in timeZone: TimeZone) -> String {
        return self.text(of: time, in: timeZone, template: "yMMMdEEE")
    }

    /// "오전 7:00". 종일 일정은 시각이 의미 없어 빈 문자열.
    static func timeText(of time: EventTime, in timeZone: TimeZone) -> String {
        guard case .allDay = time else {
            return self.text(of: time, in: timeZone, template: "jm")
        }
        return ""
    }

    private static func text(
        of time: EventTime, in timeZone: TimeZone, template: String
    ) -> String {
        let date = Date(
            timeIntervalSince1970: time.rangeWithShifttingifNeed(on: timeZone).lowerBound
        )
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}


// MARK: - DDayTargetEventEntity (1단: 일정·공휴일)

struct DDayTargetEventEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
    static let defaultQuery = DDayTargetEventQuery()

    var id: String
    var name: String
    var subtitle: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct DDayTargetCandidate {
    let targetId: DDayTargetEventId
    let name: String
    let time: EventTime
    let isRepeating: Bool
}

extension Array where Element == DDayTargetCandidate {

    /// 반복 일정 → 다가오는 순 → 지난 순(최근 먼저). 고를 확률이 높은 것을 위로 올린다.
    ///
    /// 지난 이벤트는 다가오는 것보다 후보 가치가 낮아 별도 상한을 둔다 — 한 상한을 공유하면
    /// 다가오는 이벤트가 많은 유저에게 지난 이벤트가 아예 안 보인다.
    func sortedForSuggestion(
        since todayStart: TimeInterval, upcomingLimit: Int, pastLimit: Int
    ) -> [DDayTargetCandidate] {

        let repeatings = self.filter { $0.isRepeating }
        let others = self.filter { !$0.isRepeating }

        let upcoming = others
            .filter { $0.time.lowerBoundWithFixed >= todayStart }
            .sorted { $0.time.lowerBoundWithFixed < $1.time.lowerBoundWithFixed }
            .prefix(upcomingLimit)

        let past = others
            .filter { $0.time.lowerBoundWithFixed < todayStart }
            .sorted { $0.time.lowerBoundWithFixed > $1.time.lowerBoundWithFixed }
            .prefix(pastLimit)

        return repeatings + upcoming + past
    }

    /// 지정 후보를 앞에 붙이고, 같은 일정의 자동 산출분을 걷어낸다.
    ///
    /// dedupe 키가 `targetId`가 아니라 `rawId`인 이유 — 회차가 지정된 후보(turnKey 있음)와
    /// 자동 산출 반복 행(turnKey 없음)은 targetId가 달라 둘 다 살아남는다. 회차를 다시 고르는
    /// 길은 2단 파라미터에 남아 있으므로 자동 행을 숨겨도 잃는 기능이 없다.
    func mergingPinned(_ pinned: [DDayTargetCandidate]) -> [DDayTargetCandidate] {
        return (pinned + self).removeDuplicates { $0.targetId.rawId }
    }
}

struct DDayTargetEventQuery: EntityQuery, @unchecked Sendable {

    private enum Constant {
        static let upcomingDays: Int = 365
        static let pastDays: Int = 365
        static let upcomingLimit: Int = 40
        static let pastLimit: Int = 10
    }

    private let factory: DDayTargetSelectIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    /// 저장된 id를 라벨로 복원한다 — id는 받은 문자열을 그대로 되돌려 저장값과 어긋나지 않게 한다.
    func entities(for identifiers: [String]) async throws -> [DDayTargetEventEntity] {

        let usecase = self.factory.makeEventFetchUsecase()
        let timeZone = self.factory.loadTimeZone()

        var entities: [DDayTargetEventEntity] = []
        for identifier in identifiers {
            guard let target = DDayTargetEventId(entityId: identifier),
                  let event = try? await usecase.fetchDDayTargetEvent(target)
            else { continue }
            entities.append(
                DDayTargetEventEntity(
                    id: identifier,
                    name: event.name,
                    subtitle: event.isRepeating
                        ? "widget.dday.target::repeating".localized()
                        : DDayTargetDateFormatter.dateText(of: event.time, in: timeZone)
                )
            )
        }
        return entities
    }

    func suggestedEntities() async throws -> [DDayTargetEventEntity] {

        let usecase = self.factory.makeEventFetchUsecase()
        let timeZone = self.factory.loadTimeZone()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = Date()

        guard let todayStart = calendar.dayRange(now)?.lowerBound,
              let from = calendar.addDays(-Constant.pastDays, from: now),
              let until = calendar.addDays(Constant.upcomingDays, from: now)
        else { return [] }

        let countryCode = await self.factory.makeHolidayFetchUsecase().currentCountryCode()
        let pinned = await self.pinnedCandidates()
        let events = try await usecase.fetchEvents(
            in: from.timeIntervalSince1970..<until.timeIntervalSince1970, timeZone
        )
        return self.asSuggestions(
            events.eventWithTimes, timeZone, countryCode, todayStart, pinned
        )
    }

    /// 유저가 지정한 후보. 삭제된 일정은 조회 실패로 자연히 빠진다.
    private func pinnedCandidates() async -> [DDayTargetCandidate] {

        let usecase = self.factory.makeEventFetchUsecase()
        let stored = self.factory.makeCandidateRepository().loadCandidates()

        var candidates: [DDayTargetCandidate] = []
        for candidate in stored {
            let targetId = DDayTargetEventId(
                kind: .schedule, rawId: candidate.scheduleId, turnKey: candidate.turnKey
            )
            guard let event = try? await usecase.fetchDDayTargetEvent(targetId)
            else { continue }
            candidates.append(
                DDayTargetCandidate(
                    targetId: targetId,
                    name: event.name,
                    time: event.time,
                    isRepeating: event.isRepeating
                )
            )
        }
        return candidates
    }

    private func asSuggestions(
        _ events: [any CalendarEvent],
        _ timeZone: TimeZone,
        _ countryCode: String?,
        _ todayStart: TimeInterval,
        _ pinned: [DDayTargetCandidate]
    ) -> [DDayTargetEventEntity] {

        let pinnedIds = Set(pinned.map { $0.targetId })

        return events
            .compactMap { self.asCandidate($0, countryCode) }
            .sorted { $0.time.lowerBoundWithFixed < $1.time.lowerBoundWithFixed }
            // 반복 일정은 회차마다 후보가 생기므로, 시간순 정렬 뒤 가장 이른 회차만 남긴다
            .removeDuplicates { $0.targetId }
            .sortedForSuggestion(
                since: todayStart,
                upcomingLimit: Constant.upcomingLimit,
                pastLimit: Constant.pastLimit
            )
            // 지정 후보는 티어 상한 뒤에 합친다 — 상한에 걸려 잘리면 지정한 의미가 없다.
            .mergingPinned(pinned)
            .map { candidate in
                DDayTargetEventEntity(
                    id: candidate.targetId.entityId(isRepeating: candidate.isRepeating),
                    name: candidate.name,
                    subtitle: self.subtitle(
                        of: candidate,
                        in: timeZone,
                        isPinned: pinnedIds.contains(candidate.targetId)
                    )
                )
            }
    }

    /// "지정한 후보 · 2027년 3월 15일 (월)" 계열. 반복 일정은 날짜 대신 반복 표시.
    private func subtitle(
        of candidate: DDayTargetCandidate, in timeZone: TimeZone, isPinned: Bool
    ) -> String {
        let base = candidate.isRepeating
            ? "widget.dday.target::repeating".localized()
            : DDayTargetDateFormatter.dateText(of: candidate.time, in: timeZone)
        guard isPinned else { return base }
        return "\("widget.dday.target::registered".localized()) · \(base)"
    }

    private func asCandidate(
        _ event: any CalendarEvent, _ countryCode: String?
    ) -> DDayTargetCandidate? {

        guard let time = event.eventTime else { return nil }

        switch event {
        case let schedule as ScheduleCalendarEvent:
            return DDayTargetCandidate(
                targetId: .init(kind: .schedule, rawId: schedule.eventIdWithoutTurn),
                name: schedule.name,
                time: time,
                isRepeating: schedule.isRepeating
            )

        case let holiday as HolidayCalendarEvent:
            // countryCode가 없으면(국가 미선택) 복원 키를 만들 수 없어 후보에서 뺀다.
            guard let countryCode else { return nil }
            let key = HolidayTargetKey(
                countryCode: countryCode,
                dateString: holiday.dateString,
                name: holiday.name
            )
            // HolidayCalendarEvent.isRepeating은 하드코딩 true(표시용)라 쓰지 않는다.
            // 공휴일은 연도별 개별 데이터이므로 회차 선택 대상이 아니다.
            return DDayTargetCandidate(
                targetId: .init(kind: .holiday, rawId: key.rawId),
                name: holiday.name,
                time: time,
                isRepeating: false
            )

        default:
            // 할일(todo)·외부 캘린더 이벤트는 D-day 대상에서 제외한다.
            return nil
        }
    }
}


// MARK: - DDayTargetTurnEntity (2단: 반복 회차)

struct DDayTargetTurnEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Turn"
    static let defaultQuery = DDayTargetTurnQuery()

    var id: String
    var name: String
    var subtitle: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct DDayTargetTurnQuery: EntityQuery, @unchecked Sendable {

    private enum Constant {
        static let rangeDays: Int = 365
        static let limit: Int = 50
    }

    @IntentParameterDependency<DDayWidgetConfigurationIntent>(\.$target)
    var configuration

    private let factory: DDayTargetSelectIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    /// 저장된 회차 id를 라벨로 복원한다 — turnKey로 실제 시각을 다시 조회해 표시한다.
    func entities(for identifiers: [String]) async throws -> [DDayTargetTurnEntity] {

        let timeZone = self.factory.loadTimeZone()
        let usecase = self.factory.makeEventFetchUsecase()

        var entities: [DDayTargetTurnEntity] = []
        for identifier in identifiers {
            guard let target = DDayTargetEventId(entityId: identifier),
                  let event = try? await usecase.fetchDDayTargetEvent(target)
            else { continue }
            entities.append(
                DDayTargetTurnEntity(
                    id: identifier,
                    name: DDayTargetDateFormatter.dateText(of: event.time, in: timeZone),
                    subtitle: DDayTargetDateFormatter.timeText(of: event.time, in: timeZone)
                )
            )
        }
        return entities
    }

    func suggestedEntities() async throws -> [DDayTargetTurnEntity] {

        guard let selected = self.configuration?.target,
              let target = DDayTargetEventId(entityId: selected.id),
              target.kind == .schedule
        else { return [] }

        let usecase = self.factory.makeEventFetchUsecase()
        let timeZone = self.factory.loadTimeZone()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = Date()

        guard let todayStart = calendar.dayRange(now)?.lowerBound,
              let until = calendar.addDays(Constant.rangeDays, from: now)
        else { return [] }

        let turns = try await usecase.fetchScheduleRepeatingTurns(
            target.rawId,
            in: todayStart..<until.timeIntervalSince1970,
            limit: Constant.limit
        )

        return turns.map { turn in
            DDayTargetTurnEntity(
                id: DDayTargetEventId(
                    kind: .schedule, rawId: target.rawId, turnKey: turn.time.customKey
                )
                .entityId(isRepeating: true),
                name: "widget.dday.turn::name".localized(with: turn.turn),
                subtitle: [
                    DDayTargetDateFormatter.dateText(of: turn.time, in: timeZone),
                    DDayTargetDateFormatter.timeText(of: turn.time, in: timeZone)
                ]
                .joinedNonEmpty(separator: " ")
            )
        }
    }
}


// MARK: - Intent

struct DDayWidgetConfigurationIntent: WidgetConfigurationIntent {

    static let title: LocalizedStringResource = ""

    @Parameter(title: "Event", default: nil)
    var target: DDayTargetEventEntity?

    @Parameter(title: "Turn", default: nil)
    var turn: DDayTargetTurnEntity?

    /// 반복 일정을 골랐을 때만 회차 파라미터를 노출한다 — 비반복 일정엔 고를 회차가 없다.
    ///
    /// 조건 값은 **반드시 문자열 리터럴**이어야 한다. AppIntents 메타데이터 추출기는 이 자리의
    /// 소스 텍스트를 그대로 담아서, 상수를 참조하면 그 표현식 이름이 비교 대상 문자열로 박히고
    /// 런타임 비교가 영원히 실패한다(회차 파라미터가 아예 안 뜬다).
    /// `DDayTargetEventId.repeatingIdFragment`와 같은 값이어야 하며, 어긋나면 테스트가 잡는다.
    static var parameterSummary: some ParameterSummary {
        When(\.$target, identifier: .contains, "|repeating|") {
            Summary {
                \.$target
                \.$turn
            }
        } otherwise: {
            Summary {
                \.$target
            }
        }
    }

    /// 실제로 렌더할 대상 — 회차가 지정됐으면 그것, 아니면 1단 값.
    ///
    /// 회차는 1단을 다른 이벤트로 바꿔도 남아 있을 수 있어, 같은 이벤트를 가리킬 때만 채택한다.
    var resolvedTargetId: DDayTargetEventId? {
        guard let target = self.target.flatMap({ DDayTargetEventId(entityId: $0.id) })
        else { return nil }
        guard let turn = self.turn.flatMap({ DDayTargetEventId(entityId: $0.id) }),
              turn.kind == target.kind, turn.rawId == target.rawId
        else { return target }
        return turn
    }
}
