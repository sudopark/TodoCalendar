//
//  CustomColorTheme+Mapping.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


struct CustomColorThemeJSONMapper {

    private enum SeedKey {
        static let background = "background"
        static let accent = "accent"
        static let text = "text"
        static let surface = "surface"
        static let today = "today"
        static let selectedDay = "selectedDay"
        static let holidayOrWeekEnd = "holidayOrWeekEnd"
        static let ai = "ai"
        static let form = "form"
    }

    func encodeSeeds(_ seeds: CustomColorThemeSeeds) throws -> String {
        return try self.encode(self.seedsMap(seeds))
    }

    func decodeSeeds(_ text: String) throws -> CustomColorThemeSeeds {
        return try self.seeds(from: self.decode(text))
    }

    func seedsMap(_ seeds: CustomColorThemeSeeds) -> [String: String] {
        let optionals: [String: String?] = [
            SeedKey.text: seeds.text,
            SeedKey.surface: seeds.surface,
            SeedKey.today: seeds.today,
            SeedKey.selectedDay: seeds.selectedDay,
            SeedKey.holidayOrWeekEnd: seeds.holidayOrWeekEnd,
            SeedKey.ai: seeds.ai
        ]
        let required: [String: String] = [
            SeedKey.background: seeds.background,
            SeedKey.accent: seeds.accent,
            SeedKey.form: seeds.form.rawValue
        ]
        return required.merging(optionals.compactMapValues { $0 }) { lhs, _ in lhs }
    }

    func seeds(from map: [String: String]) throws -> CustomColorThemeSeeds {
        guard let background = map[SeedKey.background],
              let accent = map[SeedKey.accent],
              let form = map[SeedKey.form].flatMap(CustomColorThemeForm.init(rawValue:))
        else {
            throw RuntimeError("invalid custom color theme seeds")
        }
        return CustomColorThemeSeeds(background: background, accent: accent, form: form)
            |> \.text .~ map[SeedKey.text]
            |> \.surface .~ map[SeedKey.surface]
            |> \.today .~ map[SeedKey.today]
            |> \.selectedDay .~ map[SeedKey.selectedDay]
            |> \.holidayOrWeekEnd .~ map[SeedKey.holidayOrWeekEnd]
            |> \.ai .~ map[SeedKey.ai]
    }

    func encodeColors(_ colors: [String: String]) throws -> String {
        return try self.encode(colors)
    }

    func decodeColors(_ text: String) throws -> [String: String] {
        return try self.decode(text)
    }

    private func encode(_ map: [String: String]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: map)
        guard let text = String(data: data, encoding: .utf8)
        else { throw RuntimeError("fail to encode custom color theme json") }
        return text
    }

    private func decode(_ text: String) throws -> [String: String] {
        guard let data = text.data(using: .utf8),
              let map = try JSONSerialization.jsonObject(with: data) as? [String: String]
        else { throw RuntimeError("invalid custom color theme json") }
        return map
    }
}


extension CustomColorTheme {

    func asJson() -> [String: Any] {
        return [
            "uuid": self.uuid,
            "name": self.name,
            "schema_version": self.schemaVersion,
            "seeds": CustomColorThemeJSONMapper().seedsMap(self.seeds),
            "colors": self.colors,
            "created_at": self.createdAt,
            "updated_at": self.updatedAt
        ]
    }
}

struct CustomColorThemeRemoteMapper: Decodable {

    private enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case schemaVersion = "schema_version"
        case seeds
        case colors
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    let theme: CustomColorTheme

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seedsMap = try container.decode([String: String].self, forKey: .seeds)
        self.theme = CustomColorTheme(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            seeds: try CustomColorThemeJSONMapper().seeds(from: seedsMap),
            colors: try container.decode([String: String].self, forKey: .colors),
            createdAt: try container.decode(TimeInterval.self, forKey: .createdAt),
            updatedAt: try container.decode(TimeInterval.self, forKey: .updatedAt)
        )
    }
}
