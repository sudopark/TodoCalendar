//
//  StubWidgetStyleUsecase.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubWidgetStyleUsecase: WidgetStyleUsecase, @unchecked Sendable {
    
    /// 프로덕션이 스타일 좌표별로 스트림을 가르므로 스텁도 좌표별로 나눈다 — 하나로 묶으면
    /// 좌표 하나를 갱신해도 다른 좌표 구독이 함께 흔들려 방출 수가 변형 수를 탄다.
    private var styleSubjects: [WidgetVariant: CurrentValueSubject<[WidgetStyle]?, Never>] = [:]
    var stubStyles: [WidgetStyle] = [] {
        didSet {
            self.styleSubjects
                .filter { $0.value.value != nil }
                .forEach { variant, subject in
                    subject.send(self.styles(in: self.stubStyles, of: variant))
                }
        }
    }
    
    private(set) var requestedVariant: WidgetVariant?
    private(set) var refreshedVariants: [WidgetVariant] = []
    private(set) var updatedStyles: [WidgetStyle] = []
    private(set) var removedStyleIds: [WidgetStyleId] = []
    private var mintedStyleIdCount: Int = 0
    
    func refreshStyles(of variant: WidgetVariant) {
        self.refreshedVariants.append(variant)
        self.subject(of: variant).send(self.styles(in: self.stubStyles, of: variant))
    }
    
    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never> {
        self.requestedVariant = variant
        return self.subject(of: variant)
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        self.requestedVariant = variant
        return self.styles(in: self.stubStyles, of: variant)
    }
    
    private func subject(
        of variant: WidgetVariant
    ) -> CurrentValueSubject<[WidgetStyle]?, Never> {
        let key = variant.styleVariant
        if let existing = self.styleSubjects[key] { return existing }
        let created = CurrentValueSubject<[WidgetStyle]?, Never>(nil)
        self.styleSubjects[key] = created
        return created
    }
    
    private func styles(
        in styles: [WidgetStyle], of variant: WidgetVariant
    ) -> [WidgetStyle] {
        return styles.filter { $0.id.variant == variant.styleVariant }
    }
    
    func updateStyle(_ style: WidgetStyle) {
        self.updatedStyles.append(style)
        self.stubStyles = self.stubStyles.map { $0.id == style.id ? style : $0 }
    }
    
    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        self.mintedStyleIdCount += 1
        return .init(variant: variant, style: .custom(id: "new\(self.mintedStyleIdCount)"))
    }
    
    func removeStyle(_ id: WidgetStyleId) {
        self.removedStyleIds.append(id)
        self.stubStyles = self.stubStyles.filter { $0.id != id }
    }
}
