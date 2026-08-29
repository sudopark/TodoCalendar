//
//  GuideLink.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum GuideLink {

    private enum Constant {
        static let base: String = "https://todo-calendar.com/guide"
    }

    /// 언어를 붙이지 않는다 — 웹이 접속 언어로 판정해 리다이렉트하므로,
    /// 원문 언어가 늘어도 앱 릴리즈 없이 따라간다.
    public static var indexPath: String {
        return Constant.base
    }

    public static var aiInputPath: String {
        let language = Locale.isCurrentKorean ? "ko" : "en"
        return "\(Constant.base)/\(language)/02-ai-input"
    }
}
