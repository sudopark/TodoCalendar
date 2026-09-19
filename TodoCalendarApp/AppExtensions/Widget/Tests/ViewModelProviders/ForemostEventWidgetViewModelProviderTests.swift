//
//  ForemostEventWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 7/17/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import UnitTestHelpKit
import TestDoubles


class ForemostEventWidgetViewModelProviderTests: XCTestCase {
    
    private func makeProvider(
        _ foremostEvent: (any ForemostMarkableEvent)?,
        shouldFail: Bool = false,
        styles: [WidgetStyleId: WidgetStyle] = [:]
    ) -> ForemostEventWidgetViewModelProvider {
        
        let usecase = PrivateStubEventFetchUsecase()
        usecase.shouldFailFetchForemost = shouldFail
        usecase.foremostEvent = foremostEvent
        
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        
        return .init(
            eventFetchUsecase: usecase,
            calendarSettingRepository: calendarSettingRepository,
            appSettingRepository: appSettingRepository,
            localeProvider: Locale.current,
            styleRepository: StubWidgetStyleRepository(styles: styles)
        )
    }
    
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var refTime: Date {
        let calenadr = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kst
        return calenadr.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 1
        }!
    }
    
    private var dummyTodo: TodoEvent {
        return TodoEvent(uuid: "todo", name: "todo")
    }
    
    private var dummySchedule: ScheduleEvent {
        return ScheduleEvent(uuid: "schedule", name: "schedule", time: .at(refTime.timeIntervalSince1970 + 10))
    }
    
    private var dummPastSchedule: ScheduleEvent {
        let past = self.refTime.add(days: -1)!
        return ScheduleEvent(uuid: "past-schedule", name: "past-schedule", time: .at(past.timeIntervalSince1970))
    }
}


extension ForemostEventWidgetViewModelProviderTests {
    
    // foremost event: todo인 경우
    func testProvider_provideForemostEvent_isTodo() async throws {
        // given
        let provider = self.makeProvider(self.dummyTodo)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertEqual(model.eventModel?.eventIdentifier, "todo")
    }
    
    // foremost event: schedule event 인 경우
    func testProvider_provideForemostEvent_isScheduleEvent() async throws {
        // given
        let provider = self.makeProvider(self.dummySchedule)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertEqual(model.eventModel?.eventIdentifier, "schedule-1")
    }
    
    // foremost event: 이미 지난 schedule event 인 경우 -> 없는것으로 취급
    func testProvider_whenForemostEventIsPastScheduleEvent_regardAsNotExists() async throws {
        // given
        let provider = self.makeProvider(self.dummPastSchedule)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertNil(model.eventModel)
    }
    
    // 없는경우 결과 nil
    func testProvider_provideFremostEvnet_notExists() async throws {
        // given
        let provider = self.makeProvider(nil)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertNil(model.eventModel)
    }
    
    // 조회 실패시 에러
    func testProvider_whenProvideFailed_error() async {
        // given
        let provider = self.makeProvider(nil, shouldFail: true)
        var failed: (any Error)?
        // when
        do {
            _ = try await provider.getViewModel(self.refTime)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
}

private final class PrivateStubEventFetchUsecase: StubCalendarEventsFetchUescase {
    
    var shouldFailFetchForemost: Bool = false
    var foremostEvent: (any ForemostMarkableEvent)?
    override func fetchForemostEvent() async throws -> ForemostEvent {
        guard self.shouldFailFetchForemost == false
        else {
            throw RuntimeError("failed")
        }
        
        return .init(foremostEvent: foremostEvent, tag: nil)
    }
}


// MARK: - 스타일 해석

extension ForemostEventWidgetViewModelProviderTests {

    private func foremostStyle(
        _ style: WidgetStyleId.Style,
        showTypeLabel: Bool = true,
        background: WidgetAppearanceSettings.Background? = nil
    ) -> (WidgetStyleId, WidgetStyle) {
        let id = WidgetStyleId(variant: .foremostSmall, style: style)
        return (
            id,
            WidgetStyle(
                id: id, name: nil,
                setting: ForemostStyleSetting.initial |> \.showTypeLabel .~ showTypeLabel,
                background: background
            )
        )
    }

    func testProvider_whenNoSavedStyle_usesInitialAndGlobalBackground() async throws {
        // given
        let provider = self.makeProvider(self.dummyTodo)

        // when
        let model = try await provider.getViewModel(self.refTime)

        // then
        XCTAssertEqual(model.style, ForemostStyleSetting.initial)
        XCTAssertEqual(model.look.background, .system)
    }

    func testProvider_whenDefaultStyleSaved_appliesItsSettingAndBackground() async throws {
        // given
        let saved = self.foremostStyle(
            .default, showTypeLabel: false, background: .custom(hex: "#101820")
        )
        let provider = self.makeProvider(self.dummyTodo, styles: [saved.0: saved.1])

        // when
        let model = try await provider.getViewModel(self.refTime)

        // then
        XCTAssertEqual(model.showsTypeLabel, false)
        XCTAssertEqual(model.look.background, .custom(hex: "#101820"))
    }

    /// 홈 2변형이 좌표 하나를 공유하므로 medium 도 같은 저장분을 읽는다.
    func testProvider_whenMediumVariant_readsSameSharedCoordinate() async throws {
        // given
        let saved = self.foremostStyle(.default, showTypeLabel: false)
        let provider = self.makeProvider(self.dummyTodo, styles: [saved.0: saved.1])

        // when
        let model = try await provider.getViewModel(self.refTime, variant: .foremostMedium)

        // then
        XCTAssertEqual(model.showsTypeLabel, false)
    }

    func testProvider_whenInstanceStyleRemoved_fallsBackToDefaultStyle() async throws {
        // given
        let def = self.foremostStyle(.default, showTypeLabel: false)
        let provider = self.makeProvider(self.dummyTodo, styles: [def.0: def.1])

        // when
        let model = try await provider.getViewModel(
            self.refTime, style: .custom(id: "removed")
        )

        // then
        XCTAssertEqual(model.showsTypeLabel, false)
    }

    /// 폴백이 스타일 단위라, 고른 스타일이 색을 안 걸었으면 기본 스타일 색을 빌려오지 않는다.
    func testProvider_whenStyleHasNoBackground_usesGlobalNotDefaultStyle() async throws {
        // given
        let def = self.foremostStyle(.default, background: .custom(hex: "#ffffff"))
        let custom = self.foremostStyle(.custom(id: "c1"))
        let provider = self.makeProvider(
            self.dummyTodo, styles: [def.0: def.1, custom.0: custom.1]
        )

        // when
        let model = try await provider.getViewModel(self.refTime, style: .custom(id: "c1"))

        // then
        XCTAssertEqual(model.look.background, .system)
    }

    /// 잠금화면 변형은 꾸미기 대상이 아니라 저장된 스타일을 읽지 않는다.
    func testProvider_whenLockScreenFamily_ignoresStyle() async throws {
        // given
        let saved = self.foremostStyle(
            .default, showTypeLabel: false, background: .custom(hex: "#101820")
        )
        let provider = self.makeProvider(self.dummyTodo, styles: [saved.0: saved.1])

        // when
        let model = try await provider.getViewModel(self.refTime, variant: .foremostInline)

        // then
        XCTAssertEqual(model.showsTypeLabel, true)
        XCTAssertEqual(model.look.background, .system)
    }
}
