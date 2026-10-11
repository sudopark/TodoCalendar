//
//  WidgetStyleResolverTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import TestDoubles

@testable import WidgetScenes


struct WidgetStyleResolverTests {

    private let variant: WidgetVariant = .monthSmall

    private func style(_ style: WidgetStyleId.Style, name: String) -> WidgetStyle {
        return .init(
            id: .init(variant: self.variant, style: style),
            name: name,
            setting: MonthStyleSetting.initial
        )
    }

    private func makeResolver(
        saved: [WidgetStyle], canRender: Bool
    ) -> WidgetStyleResolver {
        let gate = StubWidgetStylePaidFeatureGateUsecase()
        gate.canRender = canRender
        return WidgetStyleResolver(
            styleRepository: StubSavedWidgetStyleRepository(styles: saved),
            paidFeatureGateUsecase: gate
        )
    }

    @Test("저장된 커스텀을 골랐는데 렌더 권한이 없으면 잠김 에러를 던진다")
    func resolver_customSavedAndRenderDenied_throwsLocked() {
        // given
        let resolver = self.makeResolver(
            saved: [self.style(.default, name: "base"), self.style(.custom(id: "c1"), name: "night")],
            canRender: false
        )

        // when + then
        #expect(throws: WidgetCustomStyleLockedError.self) {
            try resolver.resolveStyle(of: self.variant, style: .custom(id: "c1"), at: Date())
        }
    }

    @Test("저장된 커스텀을 골랐고 렌더 권한이 있으면 그 커스텀을 돌려준다")
    func resolver_customSavedAndRenderAllowed_returnsCustom() throws {
        // given
        let resolver = self.makeResolver(
            saved: [self.style(.default, name: "base"), self.style(.custom(id: "c1"), name: "night")],
            canRender: true
        )

        // when
        let resolved = try resolver.resolveStyle(of: self.variant, style: .custom(id: "c1"), at: Date())

        // then
        #expect(resolved?.name == "night")
    }

    @Test("고른 커스텀이 지워졌으면 권한과 무관하게 기본 저장분으로 돌아간다")
    func resolver_customNotSaved_fallsBackToDefault() throws {
        // given
        let resolver = self.makeResolver(
            saved: [self.style(.default, name: "base")],
            canRender: false
        )

        // when
        let resolved = try resolver.resolveStyle(of: self.variant, style: .custom(id: "gone"), at: Date())

        // then
        #expect(resolved?.name == "base")
    }

    @Test("기본 스타일은 렌더 권한이 없어도 잠그지 않는다")
    func resolver_defaultStyle_neverAsksGate() throws {
        // given
        let resolver = self.makeResolver(
            saved: [self.style(.default, name: "base")],
            canRender: false
        )

        // when
        let resolved = try resolver.resolveStyle(of: self.variant, style: .default, at: Date())

        // then
        #expect(resolved?.name == "base")
    }

    @Test("기본 스타일 저장분이 없으면 nil 을 돌려준다")
    func resolver_defaultNotSaved_returnsNil() throws {
        // given
        let resolver = self.makeResolver(saved: [], canRender: false)

        // when
        let resolved = try resolver.resolveStyle(of: self.variant, style: .default, at: Date())

        // then
        #expect(resolved == nil)
    }
}


private final class StubSavedWidgetStyleRepository: WidgetStyleRepository, @unchecked Sendable {

    private let styles: [WidgetStyleId: WidgetStyle]
    init(styles: [WidgetStyle]) {
        self.styles = Dictionary(uniqueKeysWithValues: styles.map { ($0.id, $0) })
    }

    func loadStyle(for id: WidgetStyleId) -> WidgetStyle? {
        return self.styles[id]
    }

    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        return Array(self.styles.values)
    }

    func updateStyle(_ style: WidgetStyle) { }

    func removeStyle(_ id: WidgetStyleId) { }

    func makeDraftPhoto(from picked: Data) -> WidgetStylePhoto? { return nil }

    func makeDraftPhoto(copying photo: WidgetStylePhoto) -> WidgetStylePhoto? { return nil }
}
