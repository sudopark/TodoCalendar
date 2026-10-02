//
//  CustomColorThemeRepository.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol CustomColorThemeRepository: Sendable {

    func loadThemes() async throws -> [CustomColorTheme]
    func loadTheme(_ uuid: String) async throws -> CustomColorTheme?
    func saveTheme(_ theme: CustomColorTheme) async throws
    func removeTheme(_ uuid: String) async throws
}
