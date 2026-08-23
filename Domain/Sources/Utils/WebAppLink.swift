//
//  WebAppLink.swift
//  Domain
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum WebAppLink {

    private enum Constant {
        static let base: String = "https://todo-calendar.com"
    }

    /// 웹이 접속 언어로 판정해 리다이렉트하므로 언어를 붙이지 않는다.
    public static var homePath: String {
        return Constant.base
    }
}
