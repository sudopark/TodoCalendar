//
//  ImageTextRecognizeService.swift
//  Domain
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - ImageTextRecognizeService

public protocol ImageTextRecognizeService: Sendable {

    /// 이미지에서 인식한 텍스트를 줄 단위로 반환 (빈 줄 제외).
    /// 단순 레이아웃에서는 대체로 위→아래 순서지만, 다중 컬럼·영수증 등에서는 순서를 보장하지 않는다.
    /// 호출 Task가 취소되면 진행 중인 인식을 중단하고 `CancellationError`를 던진다.
    func recognizeTextLines(in imageData: Data) async throws -> [String]
}
