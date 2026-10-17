//
//  WidgetSceneImageAssetTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import WidgetScenes


struct WidgetSceneImageAssetTests {

    /// 갤러리는 앱 프로세스에서 위젯 뷰를 그린다 — 에셋이 확장 타겟 카탈로그에만 있으면 `Bundle.main` 으로는 못 찾는다.
    @Test(
        "위젯 뷰가 이름으로 부르는 이미지 에셋은 WidgetScenes 번들에서 해석된다",
        arguments: ["custom.calendar.badge.sparkles", "small_icon"]
    )
    func namedImageAssets_resolveFromWidgetScenesBundle(_ name: String) {
        // given + when
        let image = UIImage(named: name, in: .module, with: nil)

        // then
        #expect(image != nil)
    }
}
