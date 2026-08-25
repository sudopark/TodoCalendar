//
//  CatalogStrings.swift
//  SnapshotTestHelpKit
//
//  Created by sudo.park on 8/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public extension String {

    /// 프로덕션에 노출되지 않는 문구라 앱 리소스가 아니라 이 헬퍼 번들에서 찾는다.
    func catalogLocalized() -> String {
        return NSLocalizedString(
            self, tableName: "CatalogStrings", bundle: Bundle.module, comment: ""
        )
    }
}
