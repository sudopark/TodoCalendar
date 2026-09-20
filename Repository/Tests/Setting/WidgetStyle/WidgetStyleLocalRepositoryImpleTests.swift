//
//  WidgetStyleLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
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

    private let photoDirectory = FileManager.default.temporaryDirectory
        .appending(path: "widget-photos-\(UUID().uuidString)")

    private func makeRepository(
        storedRaw: [String: [String: String]]? = nil
    ) -> WidgetStyleLocalRepositoryImple {
        return self.makeRepository(storedRaw: storedRaw, photoDirectory: self.photoDirectory)
    }

    private func makeRepository(
        storedRaw: [String: [String: String]]? = nil,
        photoDirectory: URL?
    ) -> WidgetStyleLocalRepositoryImple {
        if let storedRaw {
            self.storage.update("widget_styles", storedRaw)
        }
        if let photoDirectory {
            try? FileManager.default.createDirectory(
                at: photoDirectory, withIntermediateDirectories: true
            )
        }
        return WidgetStyleLocalRepositoryImple(
            environmentStorage: self.storage, photoDirectory: photoDirectory
        )
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
        let nonCustomizableId = WidgetStyleId(variant: .nextEventInline, style: .default)
        let repository = self.makeRepository()
        repository.updateSetting(TodayStyleSetting.initial, for: nonCustomizableId)

        // when
        let setting = repository.loadSetting(for: nonCustomizableId)

        // then
        #expect(setting == nil)
        #expect(repository.loadStyles(of: .nextEventInline).isEmpty == true)
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


// MARK: - 사진 파일

private extension WidgetStyleLocalRepositoryImpleTests {

    var ddayId: WidgetStyleId { return .init(variant: .ddaySmall, style: .default) }

    func ddayStyle(
        style: WidgetStyleId.Style = .default,
        name: String? = nil,
        photo: WidgetStylePhoto?
    ) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: .ddaySmall, style: style),
            name: name, setting: DDayStyleSetting.initial, photo: photo
        )
    }

    func photoFiles(of photoId: String) -> (original: URL, rendering: URL) {
        return (
            self.photoDirectory.appending(path: "\(photoId).original"),
            self.photoDirectory.appending(path: "\(photoId).render.jpg")
        )
    }

    func photoDirectoryEntries() throws -> [String] {
        return try FileManager.default.contentsOfDirectory(atPath: self.photoDirectory.path())
    }

    func recordText(of id: WidgetStyleId) -> String? {
        let stored: [String: [String: String]]? = self.storage.load("widget_styles")
        return stored?[id.variant.rawValue]?[self.storageKey(of: id.style)]
    }

    func recordPhotoId(of id: WidgetStyleId) throws -> String? {
        let text = try #require(self.recordText(of: id))
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        return object?["photo"] as? String
    }

    func storageKey(of style: WidgetStyleId.Style) -> String {
        switch style {
        case .default: return "default"
        case .custom(let id): return "custom::\(id)"
        }
    }

    func makeImageData(width: Int, height: Int) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination) == true)
        return data as Data
    }

    func pixelSize(of data: Data) throws -> CGSize {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Double)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Double)
        return CGSize(width: width, height: height)
    }

    func exists(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path())
    }

    func draftPhoto(
        _ repository: WidgetStyleLocalRepositoryImple, _ picked: Data
    ) throws -> WidgetStylePhoto {
        return try #require(repository.makeDraftPhoto(from: picked))
    }

    func storedPhoto(_ id: String) -> WidgetStylePhoto {
        let files = self.photoFiles(of: id)
        return .init(id: id, original: files.original, rendering: files.rendering)
    }
}


extension WidgetStyleLocalRepositoryImpleTests {

    @Test("고른 사진은 원본·축소본 두 장으로 저장되고 레코드엔 식별자만 남는다")
    func updateStyle_whenPhotoPicked_writesBothFilesAndRecordsIdentifier() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)

        // when
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))

        // then
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let files = self.photoFiles(of: photoId)
        #expect(UUID(uuidString: photoId) != nil)
        #expect(self.exists(files.original) == true)
        #expect(self.exists(files.rendering) == true)
        #expect(try Data(contentsOf: files.original) == original)
    }

    @Test("레코드 문자열에 이미지 바이트가 들어가지 않는다")
    func updateStyle_whenPhotoPicked_recordJSONHasNoImageBytes() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)

        // when
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))

        // then
        let text = try #require(self.recordText(of: self.ddayId))
        #expect(original.count > 2000)
        #expect(text.count < 200)
    }

    @Test("레코드에 식별자가 있으면 단건 조회가 축소본을 실어 낸다")
    func loadStyle_whenRecordHasIdentifier_fillsStoredPhotoWithRenderData() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        let loaded = repository.loadStyle(for: self.ddayId)

        // then
        #expect(loaded?.photo == self.storedPhoto(photoId))
    }

    @Test("목록 조회도 같은 방식으로 사진을 채운다")
    func loadStyles_whenRecordHasIdentifier_fillsStoredPhoto() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        let styles = repository.loadStyles(of: .ddaySmall)

        // then
        #expect(styles.map { $0.photo } == [self.storedPhoto(photoId)])
    }

    @Test("축소본이 없고 원본이 있으면 조회가 원본 자리를 내준다")
    func loadStyle_whenRenderFileMissingButOriginalExists_pointsAtOriginal() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        try FileManager.default.removeItem(at: self.photoFiles(of: photoId).rendering)

        // when
        let loaded = repository.loadStyle(for: self.ddayId)

        // then
        let files = self.photoFiles(of: photoId)
        #expect(loaded?.photo?.id == photoId)
        #expect(loaded?.photo?.rendering == files.original)
    }

    @Test("조회는 축소본을 다시 만들어도 파일로 쓰지 않는다")
    func loadStyle_whenRenderFileMissingButOriginalExists_doesNotWriteFile() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let files = self.photoFiles(of: photoId)
        try FileManager.default.removeItem(at: files.rendering)

        // when
        _ = repository.loadStyle(for: self.ddayId)

        // then
        #expect(self.exists(files.rendering) == false)
        #expect(self.exists(files.original) == true)
    }

    @Test("두 장이 다 없으면 사진이 없는 스타일로 읽는다")
    func loadStyle_whenBothFilesMissing_photoIsNil() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        repository.updateStyle(self.ddayStyle(name: "밤 모드", photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let files = self.photoFiles(of: photoId)
        try FileManager.default.removeItem(at: files.rendering)
        try FileManager.default.removeItem(at: files.original)

        // when
        let loaded = repository.loadStyle(for: self.ddayId)

        // then
        #expect(loaded?.photo == nil)
        #expect(loaded?.name == "밤 모드")
    }

    @Test("컨테이너가 없으면 레코드의 사진 식별자를 그대로 둔다")
    func updateStyle_whenPhotoDirectoryIsNil_keepsRecordIdentifier() throws {
        // given
        let saving = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        saving.updateStyle(self.ddayStyle(photo: try self.draftPhoto(saving, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        let detached = self.makeRepository(photoDirectory: nil)
        detached.updateStyle(self.ddayStyle(name: "이름만 바꿈", photo: nil))

        // then
        #expect(try self.recordPhotoId(of: self.ddayId) == photoId)
        #expect(self.exists(self.photoFiles(of: photoId).original) == true)
        #expect(self.recordText(of: self.ddayId)?.contains("이름만 바꿈") == true)
    }

    @Test("저장할 때 축소본이 없으면 원본에서 다시 만들어 쓴다")
    func updateStyle_whenRenderFileMissing_repairsItFromOriginal() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let files = self.photoFiles(of: photoId)
        let loaded = try #require(repository.loadStyle(for: self.ddayId))
        try FileManager.default.removeItem(at: files.rendering)

        // when
        repository.updateStyle(loaded)

        // then
        #expect(self.exists(files.rendering) == true)
        #expect(try self.recordPhotoId(of: self.ddayId) == photoId)
    }

    @Test("저장된 사진이 그대로면 파일을 다시 쓰지 않는다")
    func updateStyle_whenStoredPhotoUnchanged_doesNotRewriteFiles() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 1200, height: 900)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let files = self.photoFiles(of: photoId)
        let sentinel = Data([0xAB, 0xCD])
        try sentinel.write(to: files.rendering)
        let loaded = try #require(repository.loadStyle(for: self.ddayId))

        // when
        repository.updateStyle(loaded)

        // then
        #expect(try Data(contentsOf: files.original) == original)
        #expect(try Data(contentsOf: files.rendering) == sentinel)
    }

    @Test("같은 식별자가 다른 좌표에도 물리면 새 식별자로 갈라낸다")
    func updateStyle_whenIdentifierSharedByAnotherStyle_forksNewIdentifier() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 800, height: 600)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let sourceId = try #require(try self.recordPhotoId(of: self.ddayId))
        let copying = try #require(repository.loadStyle(for: self.ddayId))
        let copiedId = WidgetStyleId(variant: .ddaySmall, style: .custom(id: "c1"))

        // when
        repository.updateStyle(
            self.ddayStyle(style: .custom(id: "c1"), name: "복제", photo: copying.photo)
        )

        // then
        let forkedId = try #require(try self.recordPhotoId(of: copiedId))
        #expect(forkedId != sourceId)
        #expect(try self.recordPhotoId(of: self.ddayId) == sourceId)
        #expect(try Data(contentsOf: self.photoFiles(of: forkedId).original) == original)
        #expect(self.exists(self.photoFiles(of: sourceId).original) == true)
    }

    @Test("사진을 지우면 두 장이 다 사라진다")
    func updateStyle_whenPhotoCleared_removesBothFiles() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        repository.updateStyle(self.ddayStyle(photo: nil))

        // then
        let files = self.photoFiles(of: photoId)
        #expect(try self.recordPhotoId(of: self.ddayId) == nil)
        #expect(self.exists(files.original) == false)
        #expect(self.exists(files.rendering) == false)
    }

    @Test("같은 좌표에 사진을 갈아끼우면 옛 두 장이 안 남는다")
    func updateStyle_whenPhotoReplaced_removesPreviousFiles() throws {
        // given
        let repository = self.makeRepository()
        let first = try self.makeImageData(width: 600, height: 400)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, first)))
        let firstId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        let second = try self.makeImageData(width: 700, height: 500)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, second)))

        // then
        let secondId = try #require(try self.recordPhotoId(of: self.ddayId))
        #expect(secondId != firstId)
        #expect(self.exists(self.photoFiles(of: firstId).original) == false)
        #expect(self.exists(self.photoFiles(of: firstId).rendering) == false)
        #expect(try self.photoDirectoryEntries().count == 2)
    }

    @Test("스타일을 지우면 그 좌표의 두 장도 지운다")
    func removeStyle_removesBothFiles() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))

        // when
        repository.removeStyle(self.ddayId)

        // then
        #expect(self.recordText(of: self.ddayId) == nil)
        #expect(try self.photoDirectoryEntries().isEmpty == true)
        #expect(self.exists(self.photoFiles(of: photoId).original) == false)
    }

    @Test("큰 사진의 축소본은 아카이브 면적 상한 아래로 내려간다")
    func updateStyle_whenPhotoIsOversized_renderFileIsUnderArchiveLimit() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 3000, height: 2000)

        // when
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))

        // then
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let rendering = try Data(contentsOf: self.photoFiles(of: photoId).rendering)
        let size = try self.pixelSize(of: rendering)
        #expect(size.width * size.height <= 700_000)
        #expect(max(size.width, size.height) <= 1000)
        #expect(try self.pixelSize(of: original).width == 3000)
    }

    @Test("규격보다 작은 원본은 확대하지 않는다")
    func updateStyle_whenPhotoIsSmallerThanTarget_keepsOriginalSize() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 300, height: 200)

        // when
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))

        // then
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let rendering = try Data(contentsOf: self.photoFiles(of: photoId).rendering)
        let size = try self.pixelSize(of: rendering)
        #expect(size == CGSize(width: 300, height: 200))
    }

    @Test("사진 칸이 없던 기존 저장값도 다른 필드를 그대로 지킨다")
    func loadStyle_whenStoredBeforePhotoField_keepsOtherFields() {
        // given
        let repository = self.makeRepository(
            storedRaw: ["ddaySmall": ["default": #"{"name":"밤 모드","setting":{}}"#]]
        )

        // when
        let loaded = repository.loadStyle(for: self.ddayId)

        // then
        #expect(loaded?.name == "밤 모드")
        #expect(loaded?.setting is DDayStyleSetting)
        #expect(loaded?.photo == nil)
    }

    @Test("사진을 안 받는 변형은 실린 사진을 버린다")
    func updateStyle_whenVariantDoesNotSupportPhoto_ignoresPhoto() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        let id = WidgetStyleId(variant: .todaySummarySmall, style: .default)

        // when
        repository.updateStyle(
            WidgetStyle(
                id: id, name: nil, setting: TodayStyleSetting.initial,
                photo: try self.draftPhoto(repository, original)
            )
        )

        // then
        #expect(try self.recordPhotoId(of: id) == nil)
        #expect(repository.loadStyle(for: id)?.photo == nil)
        #expect(try self.photoDirectoryEntries().isEmpty == true)
    }

    @Test("사진 파일 쓰기가 실패하면 새 식별자가 안 들어가고 옛 사진이 남는다")
    func updateStyle_whenPhotoWriteFails_keepsPreviousIdentifier() throws {
        // given
        let saving = self.makeRepository()
        let first = try self.makeImageData(width: 600, height: 400)
        saving.updateStyle(self.ddayStyle(photo: try self.draftPhoto(saving, first)))
        let firstId = try #require(try self.recordPhotoId(of: self.ddayId))
        let blocked = FileManager.default.temporaryDirectory
            .appending(path: "not-a-directory-\(UUID().uuidString)")
        try Data([0x00]).write(to: blocked)

        // when
        let broken = self.makeRepository(photoDirectory: blocked)
        broken.updateStyle(
            self.ddayStyle(
                photo: try self.draftPhoto(broken, try self.makeImageData(width: 700, height: 500))
            )
        )

        // then
        #expect(try self.recordPhotoId(of: self.ddayId) == firstId)
        #expect(self.exists(self.photoFiles(of: firstId).original) == true)
    }

    @Test("이미지로 못 읽는 바이트를 고르면 초안이 안 만들어진다")
    func makeDraftPhoto_whenPickedIsNotDecodable_isNil() throws {
        // given
        let repository = self.makeRepository()

        // when
        let draft = repository.makeDraftPhoto(from: Data([0x00, 0x01, 0x02]))

        // then
        #expect(draft == nil)
        #expect(try self.photoDirectoryEntries().isEmpty == true)
    }

    @Test("원본이 사진을 갈아끼운 뒤 복제 초안을 저장해도 복제본은 제 파일을 갖는다")
    func updateStyle_whenSourceReplacedPhotoBeforeCopyIsSaved_copyKeepsOwnFiles() throws {
        // given
        let repository = self.makeRepository()
        let first = try self.makeImageData(width: 800, height: 600)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, first)))
        let firstId = try #require(try self.recordPhotoId(of: self.ddayId))
        let source = try #require(repository.loadStyle(for: self.ddayId)?.photo)
        let copying = try #require(repository.makeDraftPhoto(copying: source))
        let copiedId = WidgetStyleId(variant: .ddaySmall, style: .custom(id: "c1"))

        // when
        let second = try self.makeImageData(width: 700, height: 500)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, second)))
        repository.updateStyle(
            self.ddayStyle(style: .custom(id: "c1"), name: "복제", photo: copying)
        )

        // then
        let copiedPhotoId = try #require(try self.recordPhotoId(of: copiedId))
        #expect(copiedPhotoId != firstId)
        #expect(self.exists(self.photoFiles(of: copiedPhotoId).original) == true)
        #expect(repository.loadStyle(for: copiedId)?.photo != nil)
    }

    @Test("복제할 원본이 사라졌어도 남은 축소본으로 초안을 뜬다")
    func makeDraftPhoto_whenOriginalIsMissing_copiesFromRendering() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 800, height: 600)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let sourceId = try #require(try self.recordPhotoId(of: self.ddayId))
        let source = try #require(repository.loadStyle(for: self.ddayId)?.photo)
        try FileManager.default.removeItem(at: self.photoFiles(of: sourceId).original)

        // when
        let copying = try #require(repository.makeDraftPhoto(copying: source))

        // then
        #expect(self.exists(copying.original) == true)
        #expect(self.exists(copying.rendering) == true)
        #expect(copying.id == nil)
    }

    @Test("파일이 사라진 저장본 좌표가 넘어오면 레코드에서 식별자를 지운다")
    func updateStyle_whenStoredPhotoFilesAreGone_clearsIdentifier() throws {
        // given
        let repository = self.makeRepository()
        let original = try self.makeImageData(width: 600, height: 400)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        let stale = try #require(repository.loadStyle(for: self.ddayId)?.photo)
        let files = self.photoFiles(of: photoId)
        try FileManager.default.removeItem(at: files.original)
        try FileManager.default.removeItem(at: files.rendering)

        // when
        repository.updateStyle(self.ddayStyle(name: "이름만 바꿈", photo: stale))

        // then
        #expect(try self.recordPhotoId(of: self.ddayId) == nil)
        #expect(self.recordText(of: self.ddayId)?.contains("이름만 바꿈") == true)
    }

    @Test("사진 디렉토리가 없어도 첫 저장이 만들어 쓴다")
    func updateStyle_whenPhotoDirectoryIsAbsent_createsItOnWrite() throws {
        // given
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "widget-photos-absent-\(UUID().uuidString)")
        let repository = WidgetStyleLocalRepositoryImple(
            environmentStorage: self.storage, photoDirectory: directory
        )
        #expect(self.exists(directory) == false)

        // when
        let original = try self.makeImageData(width: 400, height: 300)
        repository.updateStyle(self.ddayStyle(photo: try self.draftPhoto(repository, original)))

        // then
        let photoId = try #require(try self.recordPhotoId(of: self.ddayId))
        #expect(self.exists(directory.appending(path: "\(photoId).original")) == true)
        try? FileManager.default.removeItem(at: directory)
    }
}
