//
//  WidgetStyleLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain

@testable import Repository


private extension WidgetStyleLocalRepositoryImple {

    func updateSetting(_ setting: any WidgetStyleSetting, for id: WidgetStyleId) {
        self.updateStyle(WidgetStyle(id: id, name: nil, setting: setting))
    }

    func loadSetting(for id: WidgetStyleId) -> (any WidgetStyleSetting)? {
        return self.loadStyle(for: id)?.setting
    }
}


private extension WidgetStyleSetting {

    var asToday: TodayStyleSetting? { self as? TodayStyleSetting }
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
            for: .init(variant: .todaySummarySmall, style: .default)
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
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ false, for: id)
        let loaded = repository.loadSetting(for: id)?.asToday

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
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ true, for: defaultId)
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ false, for: customId)

        // then
        #expect(repository.loadSetting(for: defaultId)?.asToday?.showHolidayName == true)
        #expect(repository.loadSetting(for: customId)?.asToday?.showHolidayName == false)
    }

    @Test("꾸미기 대상이 아닌 variant 는 저장돼 있어도 설정을 내지 않는다")
    func loadSetting_whenVariantHasNoSettingType_isNil() {
        // given
        let composedId = WidgetStyleId(variant: .doubleMonthMedium, style: .default)
        let repository = self.makeRepository()
        repository.updateSetting(TodayStyleSetting.initial, for: composedId)

        // when
        let setting = repository.loadSetting(for: composedId)

        // then
        #expect(setting == nil)
        #expect(repository.loadStyles(of: .doubleMonthMedium).isEmpty == true)
    }

    @Test("한 좌표를 갱신해도 다른 좌표 설정이 남는다")
    func updateSetting_keepsOtherCoordinates() {
        // given
        let repository = self.makeRepository()
        let keptId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showTimeZone .~ false, for: keptId
        )

        // when
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ false,
            for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(repository.loadSetting(for: keptId)?.asToday?.showTimeZone == false)
    }

    @Test("구분자가 든 커스텀 id 도 그대로 복원한다")
    func updateSetting_customIdWithSeparator_roundTrips() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "a::b::c"))

        // when
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ true, for: id)

        // then
        #expect(repository.loadSetting(for: id)?.asToday?.showHolidayName == true)
        let styles = repository.loadStyles(of: .todaySummarySmall)
        #expect(styles.map { $0.id.style } == [.custom(id: "a::b::c")])
    }
}


// MARK: - 이름·저장 형식

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("스타일을 이름과 함께 저장하고 다시 읽는다")
    func updateStyle_withName_thenLoadStyles_roundTripsName() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))

        // when
        repository.updateStyle(
            WidgetStyle(id: id, name: "밤 모드", setting: TodayStyleSetting.initial |> \.showHolidayName .~ false)
        )

        // then
        let styles = repository.loadStyles(of: .todaySummarySmall)
        #expect(styles.map { $0.name } == ["밤 모드"])
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [false])
    }

    @Test("이름 없이 저장된 구버전 값도 설정이 유지된다")
    func loadStyles_whenStoredAsLegacyPayload_keepsSettingWithoutName() {
        // given
        let repository = self.makeRepository(
            storedRaw: ["todaySummarySmall": ["default": #"{"showHolidayName":true}"#]]
        )

        // when
        let styles = repository.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.name } == [nil])
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [true])
    }

    @Test("새 형식으로 저장된 값을 구버전 경로로 잘못 읽지 않는다")
    func loadStyles_whenStoredAsRecord_doesNotFallBackToLegacyDecoding() {
        // given
        let repository = self.makeRepository(
            storedRaw: [
                "todaySummarySmall": [
                    "default": #"{"name":"밤 모드","setting":{"showHolidayName":true}}"#
                ]
            ]
        )

        // when
        let styles = repository.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.name } == ["밤 모드"])
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [true])
    }

    @Test("한 variant 에 구버전 값과 새 형식 값이 섞여 있어도 둘 다 읽는다")
    func loadStyles_whenLegacyAndRecordMixed_readsBoth() {
        // given
        let repository = self.makeRepository(
            storedRaw: [
                "todaySummarySmall": [
                    "default": #"{"showHolidayName":true}"#,
                    "custom::c1": #"{"name":"밤 모드","setting":{"showHolidayName":false}}"#
                ]
            ]
        )

        // when
        let styles = repository.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.name } == [nil, "밤 모드"])
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [true, false])
    }

    @Test("단건 조회도 새 형식 저장값에서 설정을 꺼낸다")
    func loadSetting_whenStoredAsRecord_returnsSettingInside() {
        // given
        let repository = self.makeRepository(
            storedRaw: [
                "todaySummarySmall": [
                    "default": #"{"name":"밤 모드","setting":{"showHolidayName":false}}"#
                ]
            ]
        )

        // when
        let setting = repository.loadSetting(
            for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(setting?.asToday?.showHolidayName == false)
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
            TodayStyleSetting.initial |> \.showHolidayName .~ false,
            for: .init(variant: variant, style: .custom(id: "b"))
        )
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ true,
            for: .init(variant: variant, style: .custom(id: "a"))
        )
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showMonthYear .~ false,
            for: .init(variant: variant, style: .default)
        )

        // when
        let styles = repository.loadStyles(of: variant)

        // then
        #expect(styles.map { $0.id.style } == [.default, .custom(id: "a"), .custom(id: "b")])
        #expect(styles.map { $0.setting.asToday?.showMonthYear } == [false, true, true])
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [true, true, false])
    }

    @Test("다른 variant 의 스타일은 목록에 섞이지 않는다")
    func loadStyles_excludesOtherVariants() {
        // given
        let repository = self.makeRepository()
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ true, for: .init(variant: .todaySummarySmall, style: .default)
        )
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ false,
            for: .init(variant: .eventListSmall, style: .default)
        )

        // when
        let styles = repository.loadStyles(of: .todaySummarySmall)

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
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ false, for: removedId)
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ true, for: keptId)

        // when
        repository.removeStyle(removedId)

        // then
        #expect(repository.loadSetting(for: removedId)?.asToday == nil)
        #expect(repository.loadSetting(for: keptId)?.asToday?.showHolidayName == true)
    }

    @Test("variant 별로 묶고 그 안에서 스타일 축으로 가른다")
    func updateSetting_storageKeyIsBuiltFromVariantRawValueAndStyle() {
        // given
        let repository = self.makeRepository()

        // when
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ false, for: .init(variant: .todaySummarySmall, style: .default)
        )
        repository.updateSetting(
            TodayStyleSetting.initial |> \.showHolidayName .~ true,
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
        repository.updateSetting(TodayStyleSetting.initial |> \.showHolidayName .~ false, for: id)

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
            for: .init(variant: .todaySummarySmall, style: .default)
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
        let styles = repository.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.setting.asToday?.showHolidayName } == [true])
    }
}


// MARK: - 배경색

extension WidgetStyleLocalRepositoryImpleTests {

    @Test("스타일에 건 배경색을 그대로 읽는다")
    func updateStyle_withBackground_thenLoadStyle_roundTripsBackground() {
        // given
        let repository = self.makeRepository()
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))

        // when
        repository.updateStyle(
            WidgetStyle(
                id: id, name: "밤 모드", setting: TodayStyleSetting.initial,
                background: .custom(hex: "#101820")
            )
        )

        // then
        let loaded = repository.loadStyle(for: id)
        #expect(loaded?.background == .custom(hex: "#101820"))
        #expect(loaded?.name == "밤 모드")
    }

    @Test("목록 조회도 스타일마다 자기 배경색을 싣는다")
    func loadStyles_carriesBackgroundOfEachStyle() {
        // given
        let repository = self.makeRepository()
        let variant = WidgetVariant.todaySummarySmall
        repository.updateStyle(
            WidgetStyle(
                id: .init(variant: variant, style: .default), name: nil,
                setting: TodayStyleSetting.initial, background: .custom(hex: "#ffffff")
            )
        )
        repository.updateStyle(
            WidgetStyle(
                id: .init(variant: variant, style: .custom(id: "c1")), name: nil,
                setting: TodayStyleSetting.initial, background: nil
            )
        )

        // when
        let styles = repository.loadStyles(of: variant)

        // then
        #expect(styles.map { $0.background } == [.custom(hex: "#ffffff"), nil])
    }

    @Test("배경색이 없던 시절 레코드는 이름·설정을 유지한 채 배경색만 비어 있다")
    func loadStyle_whenStoredRecordHasNoBackground_keepsNameAndSetting() {
        // given
        let repository = self.makeRepository(
            storedRaw: [
                "todaySummarySmall": [
                    "default": #"{"name":"밤 모드","setting":{"showHolidayName":true}}"#
                ]
            ]
        )

        // when
        let loaded = repository.loadStyle(
            for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(loaded?.background == nil)
        #expect(loaded?.name == "밤 모드")
        #expect(loaded?.setting.asToday?.showHolidayName == true)
    }

    @Test("구버전 payload 단독 저장값도 배경색이 비어 있다")
    func loadStyle_whenStoredAsLegacyPayload_backgroundIsNil() {
        // given
        let repository = self.makeRepository(
            storedRaw: ["todaySummarySmall": ["default": #"{"showHolidayName":true}"#]]
        )

        // when
        let loaded = repository.loadStyle(
            for: .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(loaded?.background == nil)
        #expect(loaded?.setting.asToday?.showHolidayName == true)
    }
}
