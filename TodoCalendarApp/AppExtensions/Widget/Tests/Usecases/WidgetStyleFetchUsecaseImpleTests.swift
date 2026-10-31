//
//  WidgetStyleFetchUsecaseImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import TodoCalendarAppWidget
import SettingDomainInterface
import SettingDomainTesting


final class WidgetStyleFetchUsecaseImpleTests {

    private let variant: WidgetVariant = .monthSmall
    private let customStyle: WidgetStyleId.Style = .custom(id: "c1")

    private func style(_ style: WidgetStyleId.Style, name: String? = nil) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: self.variant, style: style),
            name: name,
            setting: self.variant.initialSetting!
        )
    }

    private func makeUsecase(saved: [WidgetStyle]) -> WidgetStyleFetchUsecaseImple {
        return WidgetStyleFetchUsecaseImple(
            styleRepository: StubWidgetStyleRepository(
                styles: Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            )
        )
    }
}


// MARK: - 스타일 한 건 읽기

extension WidgetStyleFetchUsecaseImpleTests {

    @Test("고른 스타일을 읽는다")
    func fetchStyle_returnsSelected() {
        // given
        let usecase = self.makeUsecase(
            saved: [self.style(.default, name: "기본"), self.style(self.customStyle, name: "여름")]
        )

        // when
        let fetched = usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched?.name == "여름")
    }

    @Test("고른 커스텀이 지워졌으면 기본 저장분을 읽는다")
    func fetchStyle_whenSelectedRemoved_returnsSavedDefault() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(.default, name: "기본")])

        // when
        let fetched = usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched?.name == "기본")
    }

    @Test("저장분이 없으면 비어 돌아온다")
    func fetchStyle_whenNothingSaved_returnsNil() {
        // given
        let usecase = self.makeUsecase(saved: [])

        // when
        let fetched = usecase.fetchStyle(of: self.variant, selected: self.customStyle)

        // then
        #expect(fetched == nil)
    }
}


// MARK: - 고를 후보

extension WidgetStyleFetchUsecaseImpleTests {

    @Test("후보는 기본 스타일을 맨 앞에 두고, 저장된 기본이 없으면 처음 설정으로 채운다")
    func fetchStyleCandidates_putsDefaultFirst() {
        // given
        let usecase = self.makeUsecase(saved: [self.style(self.customStyle, name: "여름")])

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.map { $0.id.style } == [.default, self.customStyle])
        #expect(candidates.first?.name == nil)
    }

    @Test("후보에 꾸며 저장한 기본과 커스텀이 모두 든다")
    func fetchStyleCandidates_returnsAllSavedStyles() {
        // given
        let secondCustom: WidgetStyleId.Style = .custom(id: "c2")
        let usecase = self.makeUsecase(saved: [
            self.style(self.customStyle, name: "여름"),
            self.style(.default, name: "기본"),
            self.style(secondCustom, name: "겨울")
        ])

        // when
        let candidates = usecase.fetchStyleCandidates(of: self.variant)

        // then
        #expect(candidates.first?.name == "기본")
        #expect(Set(candidates.dropFirst().map { $0.id.style }) == [self.customStyle, secondCustom])
    }
}
