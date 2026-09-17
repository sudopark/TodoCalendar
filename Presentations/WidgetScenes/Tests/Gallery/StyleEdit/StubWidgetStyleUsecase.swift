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
    
    /// 프로덕션과 같이 갱신 요청 전에는 아무것도 내보내지 않는다 — 배선 누락이 테스트에서 드러나야 한다.
    private let styleSubject = CurrentValueSubject<[WidgetStyle]?, Never>(nil)
    var stubStyles: [WidgetStyle] = [] {
        didSet {
            guard self.styleSubject.value != nil else { return }
            self.styleSubject.send(self.stubStyles)
        }
    }
    
    private(set) var requestedVariant: WidgetVariant?
    private(set) var refreshedVariants: [WidgetVariant] = []
    private(set) var updatedStyles: [WidgetStyle] = []
    private(set) var removedStyleIds: [WidgetStyleId] = []
    private var mintedStyleIdCount: Int = 0
    
    func refreshStyles(of variant: WidgetVariant) {
        self.refreshedVariants.append(variant)
        self.styleSubject.send(self.stubStyles)
    }
    
    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never> {
        self.requestedVariant = variant
        return self.styleSubject
            .compactMap { $0 }
            .map { styles in styles.filter { $0.id.variant == variant } }
            .eraseToAnyPublisher()
    }
    
    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        self.requestedVariant = variant
        return self.stubStyles.filter { $0.id.variant == variant }
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
