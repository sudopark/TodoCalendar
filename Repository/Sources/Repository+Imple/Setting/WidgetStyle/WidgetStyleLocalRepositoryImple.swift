//
//  WidgetStyleLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Domain


public final class WidgetStyleLocalRepositoryImple: WidgetStyleRepository {

    private let environmentStorage: any EnvironmentStorage
    private let photoDirectory: URL?

    public init(
        environmentStorage: any EnvironmentStorage,
        photoDirectory: URL?
    ) {
        self.environmentStorage = environmentStorage
        self.photoDirectory = photoDirectory
    }

    private enum Constant {
        static let key: String = "widget_styles"
        static let originalSuffix: String = "original"
        static let renderSuffix: String = "render.jpg"
        static let draftDirectoryName: String = "widget-style-photo-drafts"
        static let renderCompression: Double = 0.9
        static let maxRenderPixelArea: Double = 700_000
        static let maxRenderPixelSize: Double = 1000
    }

    private typealias StoredStyleTexts = [String: [String: String]]
}


// MARK: - load · update · remove

extension WidgetStyleLocalRepositoryImple {

    public func loadStyle(for id: WidgetStyleId) -> WidgetStyle? {
        guard let type = id.variant.settingType,
              let decoded = self.loadStoredStyles()[id.variant.rawValue]?[id.style.storageKey]?
                .decodedStoredStyle(type)
        else { return nil }
        return decoded.asStyle(id, photo: self.storedPhoto(of: decoded.photo))
    }

    public func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        guard let type = variant.settingType else { return [] }
        let stored = self.loadStoredStyles()[variant.rawValue] ?? [:]
        return stored
            .compactMap { key, text -> WidgetStyle? in
                guard let style = WidgetStyleId.Style(storageKey: key),
                      let stored = text.decodedStoredStyle(type)
                else { return nil }
                return stored.asStyle(
                    .init(variant: variant, style: style),
                    photo: self.storedPhoto(of: stored.photo)
                )
            }
            .sorted { $0.id.style.sortKey < $1.id.style.sortKey }
    }

    public func updateStyle(_ style: WidgetStyle) {
        let stored = self.loadStoredStyles()
        let photoId = self.syncPhotoFilesIfNeeded(for: style, in: stored)
        guard let text = style.encodedText(photoId) else { return }
        var updating = stored
        var styles = updating[style.id.variant.rawValue] ?? [:]
        styles[style.id.style.storageKey] = text
        updating[style.id.variant.rawValue] = styles
        self.saveStoredStyles(updating)
    }

    public func removeStyle(_ id: WidgetStyleId) {
        var stored = self.loadStoredStyles()
        var styles = stored[id.variant.rawValue] ?? [:]
        let removedPhotoId = styles.removeValue(forKey: id.style.storageKey)?.storedPhotoId
        stored[id.variant.rawValue] = styles.isEmpty ? nil : styles
        self.saveStoredStyles(stored)
        if let removedPhotoId { self.removePhotoFiles(of: removedPhotoId) }
    }

    private func loadStoredStyles() -> StoredStyleTexts {
        return self.environmentStorage.load(Constant.key) ?? [:]
    }

    /// 남은 스타일이 없으면 키를 지운다 — 빈 사전을 남기면 "없음"을 두 형태로 표현하게 된다.
    private func saveStoredStyles(_ stored: StoredStyleTexts) {
        guard !stored.isEmpty
        else {
            self.environmentStorage.remove(Constant.key)
            return
        }
        self.environmentStorage.update(Constant.key, stored)
    }
}


// MARK: - 사진 칸 확정 — 레코드에 박을 식별자를 내고 실물을 거기 맞춘다

extension WidgetStyleLocalRepositoryImple {

    private enum PhotoState {
        case unsupported
        case none
        case draft(WidgetStylePhoto)
        case storedButFilesGone
        case storedSharedWithOthers(String)
        case storedOwned(String)
    }

    private func syncPhotoFilesIfNeeded(
        for style: WidgetStyle, in stored: StoredStyleTexts
    ) -> String? {
        let savedId = self.savedPhotoId(of: style.id, in: stored)
        switch self.photoState(of: style, in: stored) {
        case .unsupported:
            return savedId

        case .none:
            if let savedId { self.removePhotoFiles(of: savedId) }
            return nil

        case .storedButFilesGone:
            return nil

        case .draft(let draft):
            guard let newId = self.storePhotoFiles(from: draft) else { return savedId }
            if let savedId { self.removePhotoFiles(of: savedId) }
            return newId

        case .storedSharedWithOthers(let photoId):
            return self.forkPhotoFiles(of: photoId) ?? savedId

        case .storedOwned(let photoId):
            self.repairRenderingIfNeeded(of: photoId)
            return photoId
        }
    }

    private func photoState(of style: WidgetStyle, in stored: StoredStyleTexts) -> PhotoState {
        guard self.photoDirectory != nil,
              style.id.variant.supportsPhotoBackground
        else { return .unsupported }
        guard let photo = style.photo else { return .none }
        guard let photoId = photo.id else { return .draft(photo) }
        guard self.storedPhoto(of: photoId) != nil else { return .storedButFilesGone }
        return self.isPhotoBoundElsewhere(photoId, except: style.id, in: stored)
            ? .storedSharedWithOthers(photoId)
            : .storedOwned(photoId)
    }

    private func savedPhotoId(of id: WidgetStyleId, in stored: StoredStyleTexts) -> String? {
        return stored[id.variant.rawValue]?[id.style.storageKey]?.storedPhotoId
    }

    private func isPhotoBoundElsewhere(
        _ photoId: String, except id: WidgetStyleId, in stored: StoredStyleTexts
    ) -> Bool {
        return stored.contains { variantKey, styles in
            styles.contains { styleKey, text in
                let isItself = variantKey == id.variant.rawValue
                    && styleKey == id.style.storageKey
                return !isItself && text.storedPhotoId == photoId
            }
        }
    }
}


// MARK: - 초안 — 임시 파일

extension WidgetStyleLocalRepositoryImple {

    public func makeDraftPhoto(from picked: Data) -> WidgetStylePhoto? {
        guard let rendering = self.downsampled(picked) else { return nil }
        return self.writeDraftFiles { urls in
            try picked.write(to: urls.original, options: .atomic)
            try rendering.write(to: urls.rendering, options: .atomic)
        }
    }

    public func makeDraftPhoto(copying photo: WidgetStylePhoto) -> WidgetStylePhoto? {
        let original = self.exists(photo.original) ? photo.original : photo.rendering
        let rendering = self.exists(photo.rendering) ? photo.rendering : photo.original
        return self.writeDraftFiles { urls in
            try FileManager.default.copyItem(at: original, to: urls.original)
            try FileManager.default.copyItem(at: rendering, to: urls.rendering)
        }
    }

    private func writeDraftFiles(
        _ write: ((original: URL, rendering: URL)) throws -> Void
    ) -> WidgetStylePhoto? {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: Constant.draftDirectoryName)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let urls = self.photoURLs(of: UUID().uuidString, in: directory)
        do {
            try write(urls)
            return WidgetStylePhoto(id: nil, original: urls.original, rendering: urls.rendering)
        } catch {
            self.removeFiles(urls)
            return nil
        }
    }
}


// MARK: - 저장본 — 공유 컨테이너

extension WidgetStyleLocalRepositoryImple {

    private func storePhotoFiles(from draft: WidgetStylePhoto) -> String? {
        guard let directory = self.photoDirectory else { return nil }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let id = UUID().uuidString
        let urls = self.photoURLs(of: id, in: directory)
        do {
            try FileManager.default.copyItem(at: draft.original, to: urls.original)
            try FileManager.default.copyItem(at: draft.rendering, to: urls.rendering)
            self.removeFiles((draft.original, draft.rendering))
            return id
        } catch {
            self.removeFiles(urls)
            return nil
        }
    }

    private func storedPhoto(of id: String?) -> WidgetStylePhoto? {
        guard let id, let urls = self.containerPhotoURLs(of: id),
              self.exists(urls.original) || self.exists(urls.rendering)
        else { return nil }
        let rendering = self.exists(urls.rendering) ? urls.rendering : urls.original
        return WidgetStylePhoto(id: id, original: urls.original, rendering: rendering)
    }

    private func forkPhotoFiles(of id: String) -> String? {
        guard let urls = self.containerPhotoURLs(of: id) else { return nil }
        let draft = WidgetStylePhoto(id: nil, original: urls.original, rendering: urls.rendering)
        guard let forked = self.makeDraftPhoto(copying: draft) else { return nil }
        return self.storePhotoFiles(from: forked)
    }

    private func repairRenderingIfNeeded(of id: String) {
        guard let urls = self.containerPhotoURLs(of: id),
              self.exists(urls.rendering) == false,
              let original = try? Data(contentsOf: urls.original),
              let rendering = self.downsampled(original)
        else { return }
        try? rendering.write(to: urls.rendering, options: .atomic)
    }

    private func removePhotoFiles(of id: String) {
        guard let urls = self.containerPhotoURLs(of: id) else { return }
        self.removeFiles(urls)
    }

    private func containerPhotoURLs(of id: String) -> (original: URL, rendering: URL)? {
        guard let directory = self.photoDirectory else { return nil }
        return self.photoURLs(of: id, in: directory)
    }

    private func photoURLs(of id: String, in directory: URL) -> (original: URL, rendering: URL) {
        return (
            directory.appending(path: "\(id).\(Constant.originalSuffix)"),
            directory.appending(path: "\(id).\(Constant.renderSuffix)")
        )
    }

    private func removeFiles(_ urls: (original: URL, rendering: URL)) {
        try? FileManager.default.removeItem(at: urls.original)
        try? FileManager.default.removeItem(at: urls.rendering)
    }

    private func exists(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path())
    }
}


// MARK: - 다운샘플 — 저장 시점 한 번

private extension WidgetStyleLocalRepositoryImple {

    func downsampled(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let pixelSize = self.pixelSize(of: source)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: self.renderMaxPixelSize(of: pixelSize)
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return self.jpegData(of: thumbnail)
    }

    func pixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0
        else { return nil }
        return CGSize(width: width, height: height)
    }

    func renderMaxPixelSize(of size: CGSize) -> Int {
        let longest = max(size.width, size.height)
        let sideScale = Constant.maxRenderPixelSize / longest
        let areaScale = (Constant.maxRenderPixelArea / (size.width * size.height)).squareRoot()
        let notEnlargingScale = min(sideScale, areaScale, 1)
        return Int((longest * notEnlargingScale).rounded(.down))
    }

    func jpegData(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: Constant.renderCompression
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}


// MARK: - WidgetStyleId.Style + storage key

private extension WidgetStyleId.Style {

    private enum Constant {
        static let defaultKey: String = "default"
        static let customPrefix: String = "custom::"
    }

    /// `default` / `custom::<id>`
    var storageKey: String {
        switch self {
        case .default: return Constant.defaultKey
        case .custom(let id): return "\(Constant.customPrefix)\(id)"
        }
    }

    /// 기본 스타일이 커스텀보다 앞선다 — 빈 문자열이 어떤 id 보다도 작다.
    var sortKey: String {
        switch self {
        case .default: return ""
        case .custom(let id): return id
        }
    }

    init?(storageKey: String) {
        if storageKey == Constant.defaultKey {
            self = .default
            return
        }
        guard storageKey.hasPrefix(Constant.customPrefix) else { return nil }
        self = .custom(id: String(storageKey.dropFirst(Constant.customPrefix.count)))
    }
}


// MARK: - 저장 레코드

private struct StoredStyle<S: WidgetStyleSetting>: Codable {

    let name: String?
    let setting: S
    let background: WidgetAppearanceSettings.Background?
    let photo: String?
}

private struct StoredPhotoField: Decodable {

    let photo: String?
}

private struct DecodedStyle {

    let name: String?
    let setting: any WidgetStyleSetting
    let background: WidgetAppearanceSettings.Background?
    let photo: String?

    func asStyle(_ id: WidgetStyleId, photo: WidgetStylePhoto?) -> WidgetStyle {
        return WidgetStyle(
            id: id, name: self.name, setting: self.setting,
            background: self.background, photo: photo
        )
    }
}

private extension WidgetStyle {

    /// 반환 타입에 payload 타입이 안 나와 존재 타입인 setting 을 그대로 넘겨 열 수 있다.
    func encodedText(_ photoId: String?) -> String? {
        return self.encodedText(self.setting, photoId)
    }

    private func encodedText<S: WidgetStyleSetting>(_ setting: S, _ photoId: String?) -> String? {
        let stored = StoredStyle(
            name: self.name, setting: setting, background: self.background, photo: photoId
        )
        return (try? JSONEncoder().encode(stored))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

private extension String {

    var storedPhotoId: String? {
        guard let data = self.data(using: .utf8) else { return nil }
        return (try? JSONDecoder().decode(StoredPhotoField.self, from: data))?.photo
    }

    func decodedStoredStyle(_ type: any WidgetStyleSetting.Type) -> DecodedStyle? {
        return self.decodedStoredStyle(typed: type)
    }

    /// 레코드를 먼저 본다 — 설정 타입은 전 필드가 Optional 이라 순서를 뒤집으면 레코드 JSON 도
    /// payload 로 디코드에 성공해 설정이 통째로 비워진다.
    private func decodedStoredStyle<S: WidgetStyleSetting>(typed type: S.Type) -> DecodedStyle? {
        guard let data = self.data(using: .utf8) else { return nil }
        if let stored = try? JSONDecoder().decode(StoredStyle<S>.self, from: data) {
            return DecodedStyle(
                name: stored.name, setting: stored.setting,
                background: stored.background, photo: stored.photo
            )
        }
        guard let setting = try? JSONDecoder().decode(type, from: data) else { return nil }
        return DecodedStyle(name: nil, setting: setting, background: nil, photo: nil)
    }
}
