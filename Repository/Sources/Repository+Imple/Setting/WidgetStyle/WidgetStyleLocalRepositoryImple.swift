//
//  WidgetStyleLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class WidgetStyleLocalRepositoryImple: WidgetStyleRepository {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private enum Constant {
        static let key: String = "widget_styles"
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
        return decoded.asStyle(id)
    }

    public func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        guard let type = variant.settingType else { return [] }
        let stored = self.loadStoredStyles()[variant.rawValue] ?? [:]
        return stored
            .compactMap { key, text -> WidgetStyle? in
                guard let style = WidgetStyleId.Style(storageKey: key),
                      let stored = text.decodedStoredStyle(type)
                else { return nil }
                return stored.asStyle(.init(variant: variant, style: style))
            }
            .sorted { $0.id.style.sortKey < $1.id.style.sortKey }
    }

    public func updateStyle(_ style: WidgetStyle) {
        guard let text = style.encodedText() else { return }
        var stored = self.loadStoredStyles()
        var styles = stored[style.id.variant.rawValue] ?? [:]
        styles[style.id.style.storageKey] = text
        stored[style.id.variant.rawValue] = styles
        self.saveStoredStyles(stored)
    }

    public func removeStyle(_ id: WidgetStyleId) {
        var stored = self.loadStoredStyles()
        var styles = stored[id.variant.rawValue] ?? [:]
        styles.removeValue(forKey: id.style.storageKey)
        stored[id.variant.rawValue] = styles.isEmpty ? nil : styles
        self.saveStoredStyles(stored)
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
}

private struct DecodedStyle {

    let name: String?
    let setting: any WidgetStyleSetting
    let background: WidgetAppearanceSettings.Background?

    func asStyle(_ id: WidgetStyleId) -> WidgetStyle {
        return WidgetStyle(
            id: id, name: self.name, setting: self.setting, background: self.background
        )
    }
}

private extension WidgetStyle {

    /// 반환 타입에 payload 타입이 안 나와 존재 타입인 setting 을 그대로 넘겨 열 수 있다.
    func encodedText() -> String? {
        return self.encodedText(self.setting)
    }

    private func encodedText<S: WidgetStyleSetting>(_ setting: S) -> String? {
        let stored = StoredStyle(
            name: self.name, setting: setting, background: self.background
        )
        return (try? JSONEncoder().encode(stored))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

private extension String {

    func decodedStoredStyle(_ type: any WidgetStyleSetting.Type) -> DecodedStyle? {
        return self.decodedStoredStyle(typed: type)
    }

    /// 레코드를 먼저 본다 — 설정 타입은 전 필드가 Optional 이라 순서를 뒤집으면 레코드 JSON 도
    /// payload 로 디코드에 성공해 설정이 통째로 비워진다.
    private func decodedStoredStyle<S: WidgetStyleSetting>(typed type: S.Type) -> DecodedStyle? {
        guard let data = self.data(using: .utf8) else { return nil }
        if let stored = try? JSONDecoder().decode(StoredStyle<S>.self, from: data) {
            return DecodedStyle(
                name: stored.name, setting: stored.setting, background: stored.background
            )
        }
        guard let setting = try? JSONDecoder().decode(type, from: data) else { return nil }
        return DecodedStyle(name: nil, setting: setting, background: nil)
    }
}
