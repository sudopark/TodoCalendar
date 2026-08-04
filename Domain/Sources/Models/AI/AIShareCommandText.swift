//
//  AIShareCommandText.swift
//  Domain
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 공유 시트로 들어온 생 텍스트를 AI가 해석할 수 있는 command_text로 조립한다.
/// 공유 원문에는 의도(일정으로 넣어달라)가 없어서 해석 지시를 클라에서 앞에 붙인다.
/// 지시문이 영문인 것과 응답 언어는 무관 — 응답 언어는 Accept-Language 헤더가 정한다.
public struct AIShareCommandText: Sendable, Equatable {

    private enum Constant {
        static let instruction: String = "Interpret the shared text below and add the matching schedule or todo to my calendar."
        static let sharedTextHeader: String = "[Shared text]"
        static let additionalInstructionHeader: String = "[Additional instruction]"
    }

    public let sharedText: String
    public var additionalInstruction: String?

    public init(sharedText: String, additionalInstruction: String? = nil) {
        self.sharedText = sharedText
        self.additionalInstruction = additionalInstruction
    }
}

extension AIShareCommandText {

    public var isEmpty: Bool {
        return self.trimmedSharedText.isEmpty
    }

    public var commandText: String {
        let sections = [
            Constant.instruction,
            "\(Constant.sharedTextHeader)\n\(self.trimmedSharedText)",
            self.trimmedAdditionalInstruction.map { "\(Constant.additionalInstructionHeader)\n\($0)" }
        ]
        return sections.compactMap { $0 }.joined(separator: "\n\n")
    }

    private var trimmedSharedText: String {
        return self.sharedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAdditionalInstruction: String? {
        return self.additionalInstruction
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
