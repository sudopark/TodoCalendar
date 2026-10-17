//
//  CustomColorTheme.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum CustomColorThemeForm: String, Sendable {
    case filled
    case grouped
    case outlined
}


public struct CustomColorThemeSeeds: Equatable, Sendable {

    public let background: String
    public let accent: String
    public var text: String?
    public var surface: String?
    public var today: String?
    public var selectedDay: String?
    public var holidayOrWeekEnd: String?
    public var ai: String?
    public let form: CustomColorThemeForm

    public init(
        background: String,
        accent: String,
        form: CustomColorThemeForm
    ) {
        self.background = background
        self.accent = accent
        self.form = form
    }
}


public struct CustomColorTheme: Equatable, Sendable {

    public let uuid: String
    public let name: String
    public let schemaVersion: Int
    public let seeds: CustomColorThemeSeeds
    public let colors: [String: String]
    public let createdAt: TimeInterval
    public let updatedAt: TimeInterval

    public init(
        uuid: String,
        name: String,
        schemaVersion: Int,
        seeds: CustomColorThemeSeeds,
        colors: [String: String],
        createdAt: TimeInterval,
        updatedAt: TimeInterval
    ) {
        self.uuid = uuid
        self.name = name
        self.schemaVersion = schemaVersion
        self.seeds = seeds
        self.colors = colors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
