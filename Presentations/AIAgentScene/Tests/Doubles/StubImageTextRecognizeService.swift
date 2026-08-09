//
//  StubImageTextRecognizeService.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


final class StubImageTextRecognizeService: ImageTextRecognizeService, @unchecked Sendable {

    private let lines: [String]
    private let error: (any Error)?

    init(lines: [String], error: (any Error)?) {
        self.lines = lines
        self.error = error
    }

    func recognizeTextLines(in imageData: Data) async throws -> [String] {
        if let error { throw error }
        return self.lines
    }
}
