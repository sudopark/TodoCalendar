//
//  Locale+AppLanguage.swift
//  Domain
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

extension Locale {

    public static var isCurrentKorean: Bool {
        return Locale.current.language.languageCode == .korean
    }
}
