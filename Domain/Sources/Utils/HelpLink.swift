//
//  HelpLink.swift
//  Domain
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum HelpLink {

    public static let koPath = "https://readmind.notion.site/To-do-Calendar-36cba0bdc84b44de9abdfd7d8721cd91"
    public static let enPath = "https://readmind.notion.site/To-do-Calendar-Help-a2183ee1a41946faa8e0658640fb4c6a?pvs=4"

    public static var currentPath: String {
        let isKorean = Locale.current.language.languageCode == .korean
        return isKorean ? self.koPath : self.enPath
    }
}
