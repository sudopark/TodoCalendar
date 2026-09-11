//
//  WidgetStyleLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


private struct DummyTodayStyle: WidgetStyleSetting {

    var showHolidayName: Bool?

    init() { }

    init(showHolidayName: Bool?) {
        self.showHolidayName = showHolidayName
    }
}

private struct DummyMonthStyle: WidgetStyleSetting {

    var showWeekDayHeader: Bool?
    var accentToday: Bool?

    init() { }

    init(showWeekDayHeader: Bool?, accentToday: Bool?) {
        self.showWeekDayHeader = showWeekDayHeader
        self.accentToday = accentToday
    }
}


struct WidgetStyleLocalRepositoryImpleTests {

    private let storage = FakeEnvironmentStorage()

    private func makeRepository(
        storedRaw: [String: [String: String]]? = nil
    ) -> WidgetStyleLocalRepositoryImple {
        if let storedRaw {
            self.storage.update("widget_styles", storedRaw)
        }
        return WidgetStyleLocalRepositoryImple(environmentStorage: self.storage)
    }
}


// MARK: - 단건 조회·갱신

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("저장한 적 없는 좌표는 설정을 내지 않는다")
    func loadSetting_whenNeverSaved_isNil() {
        // given
        let repository = self.makeRepository()

        // when
        let setting = repository.loadSetting(
            DummyTodayStyle.self, for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(setting == nil)
    }

    @Test("저장한 설정을 그대로 읽는다")
    func updateSetting_thenLoad_roundTrips() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .default)

        // when
        repository.updateSetting(DummyTodayStyle(showHolidayName: false), for: id)
        let loaded = repository.loadSetting(DummyTodayStyle.self, for: id)

        // then
        #expect(loaded?.showHolidayName == false)
    }

    @Test("같은 variant 의 기본 스타일과 커스텀 스타일이 따로 산다")
    func updateSetting_defaultAndCustomDoNotOverwriteEachOther() {
        // given
        let repository = self.makeRepository()
        let defaultId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        let customId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))

        // when
        repository.updateSetting(DummyTodayStyle(showHolidayName: true), for: defaultId)
        repository.updateSetting(DummyTodayStyle(showHolidayName: false), for: customId)

        // then
        #expect(repository.loadSetting(DummyTodayStyle.self, for: defaultId)?.showHolidayName == true)
        #expect(repository.loadSetting(DummyTodayStyle.self, for: customId)?.showHolidayName == false)
    }

    @Test("variant 가 달라도 각자 다른 타입의 설정을 왕복한다")
    func updateSetting_differentVariantsKeepOwnPayloadTypes() {
        // given
        let repository = self.makeRepository()
        let todayId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        let monthId = WidgetStyleId(variant: .monthSmall, style: .default)
        let monthSetting = DummyMonthStyle(showWeekDayHeader: false, accentToday: true)

        // when
        repository.updateSetting(DummyTodayStyle(showHolidayName: false), for: todayId)
        repository.updateSetting(monthSetting, for: monthId)

        // then
        #expect(repository.loadSetting(DummyTodayStyle.self, for: todayId)?.showHolidayName == false)
        let loadedMonth = repository.loadSetting(DummyMonthStyle.self, for: monthId)
        #expect(loadedMonth?.showWeekDayHeader == false)
        #expect(loadedMonth?.accentToday == true)
    }

    @Test("한 좌표를 갱신해도 다른 좌표 설정이 남는다")
    func updateSetting_keepsOtherCoordinates() {
        // given
        let repository = self.makeRepository()
        let keptId = WidgetStyleId(variant: .monthSmall, style: .default)
        let kept = DummyMonthStyle(showWeekDayHeader: nil, accentToday: true)
        repository.updateSetting(kept, for: keptId)

        // when
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: false),
            for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(repository.loadSetting(DummyMonthStyle.self, for: keptId)?.accentToday == true)
    }

    @Test("구분자가 든 커스텀 id 도 그대로 복원한다")
    func updateSetting_customIdWithSeparator_roundTrips() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "a::b::c"))

        // when
        repository.updateSetting(DummyTodayStyle(showHolidayName: true), for: id)

        // then
        #expect(repository.loadSetting(DummyTodayStyle.self, for: id)?.showHolidayName == true)
        let styles: [WidgetStyle<DummyTodayStyle>] = repository.loadStyles(
            DummyTodayStyle.self, of: .todaySummarySmall
        )
        #expect(styles.map { $0.id.style } == [.custom(id: "a::b::c")])
    }
}


// MARK: - 목록 조회

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("variant 의 스타일을 기본 먼저·커스텀 id 순으로 낸다")
    func loadStyles_ordersDefaultFirstThenCustomById() {
        // given
        let repository = self.makeRepository()
        let variant = WidgetVariant.todaySummarySmall
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: false),
            for: .init(variant: variant, style: .custom(id: "b"))
        )
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: true),
            for: .init(variant: variant, style: .custom(id: "a"))
        )
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: nil), for: .init(variant: variant, style: .default)
        )

        // when
        let styles: [WidgetStyle<DummyTodayStyle>] = repository.loadStyles(
            DummyTodayStyle.self, of: variant
        )

        // then
        #expect(styles.map { $0.id.style } == [.default, .custom(id: "a"), .custom(id: "b")])
        #expect(styles.map { $0.setting.showHolidayName } == [nil, true, false])
    }

    @Test("다른 variant 의 스타일은 목록에 섞이지 않는다")
    func loadStyles_excludesOtherVariants() {
        // given
        let repository = self.makeRepository()
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: true), for: .init(variant: .todaySummarySmall, style: .default)
        )
        let monthSetting = DummyMonthStyle(showWeekDayHeader: nil, accentToday: true)
        repository.updateSetting(monthSetting, for: .init(variant: .monthSmall, style: .default))

        // when
        let styles: [WidgetStyle<DummyTodayStyle>] = repository.loadStyles(
            DummyTodayStyle.self, of: .todaySummarySmall
        )

        // then
        #expect(styles.map { $0.id.variant } == [.todaySummarySmall])
    }
}


// MARK: - 삭제

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("스타일을 지우면 그 좌표가 사라진다")
    func removeStyle_dropsThatCoordinateOnly() {
        // given
        let repository = self.makeRepository()
        let removedId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))
        let keptId = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        repository.updateSetting(DummyTodayStyle(showHolidayName: false), for: removedId)
        repository.updateSetting(DummyTodayStyle(showHolidayName: true), for: keptId)

        // when
        repository.removeStyle(removedId)

        // then
        #expect(repository.loadSetting(DummyTodayStyle.self, for: removedId) == nil)
        #expect(repository.loadSetting(DummyTodayStyle.self, for: keptId)?.showHolidayName == true)
    }

    @Test("variant 별로 묶고 그 안에서 스타일 축으로 가른다")
    func updateSetting_storageKeyIsBuiltFromVariantRawValueAndStyle() {
        // given
        let repository = self.makeRepository()

        // when
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: false), for: .init(variant: .todaySummarySmall, style: .default)
        )
        repository.updateSetting(
            DummyTodayStyle(showHolidayName: true),
            for: .init(variant: .monthSmall, style: .custom(id: "c1"))
        )

        // then
        let raw: [String: [String: String]]? = self.storage.load("widget_styles")
        #expect(raw?.keys.sorted() == ["monthSmall", "todaySummarySmall"])
        #expect(raw?["todaySummarySmall"]?.keys.sorted() == ["default"])
        #expect(raw?["monthSmall"]?.keys.sorted() == ["custom::c1"])
    }

    @Test("마지막 스타일을 지우면 저장 키 자체를 지운다")
    func removeStyle_whenLastOne_removesStorageKey() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .default)
        repository.updateSetting(DummyTodayStyle(showHolidayName: false), for: id)

        // when
        repository.removeStyle(id)

        // then
        let raw: [String: [String: String]]? = self.storage.load("widget_styles")
        #expect(raw == nil)
    }
}


// MARK: - 저장값이 어긋난 경우

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("깨진 JSON 이 저장돼 있으면 설정을 내지 않는다")
    func loadSetting_whenStoredTextIsNotDecodable_isNil() {
        // given
        let repository = self.makeRepository(
            storedRaw: ["todaySummarySmall": ["default": "not a json"]]
        )

        // when
        let setting = repository.loadSetting(
            DummyTodayStyle.self, for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(setting == nil)
    }

    @Test("형식이 어긋난 스타일 키는 목록에서 건너뛴다")
    func loadStyles_skipsMalformedKey() {
        // given
        let repository = self.makeRepository(
            storedRaw: [
                "todaySummarySmall": [
                    "default": #"{"showHolidayName":true}"#,
                    "custom": #"{"showHolidayName":false}"#,
                    "unknownMark::c1": #"{"showHolidayName":false}"#
                ]
            ]
        )

        // when
        let styles: [WidgetStyle<DummyTodayStyle>] = repository.loadStyles(
            DummyTodayStyle.self, of: .todaySummarySmall
        )

        // then
        #expect(styles.map { $0.setting.showHolidayName } == [true])
    }
}
