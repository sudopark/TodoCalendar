//
//  AIShareCommandTextTests.swift
//  Domain
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import Domain


final class AIShareCommandTextTests { }


// MARK: - command_text 조립

extension AIShareCommandTextTests {

    @Test("부가 지시가 없으면 지시문 + 공유 원문만 조립한다")
    func commandText_withoutAdditionalInstruction() {
        // given
        let sut = AIShareCommandText(sharedText: "9월 10일 약속")

        // when
        let text = sut.commandText

        // then
        let expected = """
        Interpret the shared text below and add the matching schedule or todo to my calendar.

        [Shared text]
        9월 10일 약속
        """
        #expect(text == expected)
    }

    @Test("부가 지시가 있으면 별도 구획으로 덧붙인다")
    func commandText_withAdditionalInstruction() {
        // given
        let sut = AIShareCommandText(
            sharedText: "9월 10일 약속",
            additionalInstruction: "오후 3시로 잡아줘"
        )

        // when
        let text = sut.commandText

        // then
        let expected = """
        Interpret the shared text below and add the matching schedule or todo to my calendar.

        [Shared text]
        9월 10일 약속

        [Additional instruction]
        오후 3시로 잡아줘
        """
        #expect(text == expected)
    }

    @Test("공유 원문과 부가 지시의 앞뒤 공백은 제거된다")
    func commandText_trimsWhitespace() {
        // given
        let sut = AIShareCommandText(
            sharedText: "  9월 10일 약속\n\n",
            additionalInstruction: "\t오후 3시로 잡아줘  "
        )

        // when
        let text = sut.commandText

        // then
        #expect(text.contains("[Shared text]\n9월 10일 약속\n") == true)
        #expect(text.hasSuffix("[Additional instruction]\n오후 3시로 잡아줘") == true)
    }

    @Test("부가 지시가 공백뿐이면 해당 구획을 생략한다")
    func commandText_ignoresBlankAdditionalInstruction() {
        // given
        let sut = AIShareCommandText(sharedText: "9월 10일 약속", additionalInstruction: "   ")

        // when
        let text = sut.commandText

        // then
        #expect(text.contains("[Additional instruction]") == false)
    }
}


// MARK: - 비어있음 판정

extension AIShareCommandTextTests {

    @Test("공유 원문이 공백뿐이면 비어있는 것으로 판정한다")
    func isEmpty_whenSharedTextIsBlank() {
        // given
        let blank = AIShareCommandText(sharedText: " \n ", additionalInstruction: "뭐라도")
        let notBlank = AIShareCommandText(sharedText: "9월 10일 약속")

        // when + then
        #expect(blank.isEmpty == true)
        #expect(notBlank.isEmpty == false)
    }
}
