//
//  AppDeepLink.swift
//  Domain
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum AppDeepLink {

    private enum Constant {
        static let scheme: String = "tc.app"
    }

    public static var scheme: String {
        return Constant.scheme
    }
}
