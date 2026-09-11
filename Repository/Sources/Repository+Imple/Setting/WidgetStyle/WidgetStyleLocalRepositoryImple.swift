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

    private typealias StoredStyles = [String: [String: String]]
}


// MARK: - load · update · remove

extension WidgetStyleLocalRepositoryImple {

    public func loadSetting<S: WidgetStyleSetting>(_ type: S.Type, for id: WidgetStyleId) -> S? {
        return self.loadStoredStyles()[id.variant.rawValue]?[id.style.storageKey]?
            .decodedSetting(type)
    }

    public func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>] {
        let stored = self.loadStoredStyles()[variant.rawValue] ?? [:]
        return stored
            .compactMap { key, text -> WidgetStyle<S>? in
                guard let style = WidgetStyleId.Style(storageKey: key),
                      let setting = text.decodedSetting(type)
                else { return nil }
                return WidgetStyle(id: .init(variant: variant, style: style), setting: setting)
            }
            .sorted { $0.id.style.sortKey < $1.id.style.sortKey }
    }

    public func updateSetting<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId) {
        guard let text = setting.encodedText() else { return }
        var stored = self.loadStoredStyles()
        var styles = stored[id.variant.rawValue] ?? [:]
        styles[id.style.storageKey] = text
        stored[id.variant.rawValue] = styles
        self.saveStoredStyles(stored)
    }

    public func removeStyle(_ id: WidgetStyleId) {
        var stored = self.loadStoredStyles()
        var styles = stored[id.variant.rawValue] ?? [:]
        styles.removeValue(forKey: id.style.storageKey)
        stored[id.variant.rawValue] = styles.isEmpty ? nil : styles
        self.saveStoredStyles(stored)
    }

    private func loadStoredStyles() -> StoredStyles {
        return self.environmentStorage.load(Constant.key) ?? [:]
    }

    /// 남은 스타일이 없으면 키를 지운다 — 빈 사전을 남기면 "없음"을 두 형태로 표현하게 된다.
    private func saveStoredStyles(_ stored: StoredStyles) {
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


// MARK: - JSON 한 겹 감싸기

private extension WidgetStyleSetting {

    func encodedText() -> String? {
        return (try? JSONEncoder().encode(self))
            .flatMap { String(data: $0, encoding: .utf8) }
    }
}

private extension String {

    func decodedSetting<S: WidgetStyleSetting>(_ type: S.Type) -> S? {
        return self.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
