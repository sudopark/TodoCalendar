//
//  AIUsageGuideLink.swift
//  Scenes
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum AIUsageGuideLink {

    // 전용 사용법 페이지 제작 전까지 기존 도움말 페이지로 연결 (#768 후속에서 교체)
    public static let koPath = "https://readmind.notion.site/To-do-Calendar-36cba0bdc84b44de9abdfd7d8721cd91"
    public static let enPath = "https://readmind.notion.site/To-do-Calendar-Help-a2183ee1a41946faa8e0658640fb4c6a?pvs=4"

    public static var currentPath: String {
        let isKorean = Locale.current.language.languageCode == .korean
        return isKorean ? self.koPath : self.enPath
    }
}
